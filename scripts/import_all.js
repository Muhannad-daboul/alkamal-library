/**
 * استيراد الأرشيف الكامل من مجلد akp إلى Firebase
 * الهيكل: akp/{سنة}/{فصل}/{كلية}/{مستوى}/{مادة}/N.pdf
 * الاستخدام: node scripts/import_all.js [--dry-run] [--concurrency=10]
 */
const { execSync } = require('child_process');
const fs   = require('fs');
const path = require('path');

// ─── إعدادات ────────────────────────────────────────────────
const ROOT          = '/Users/muhannaddaboul/Desktop/akp';
const FIREBASE_PROJECT  = 'alkamal-library';
const STORAGE_BUCKET    = 'alkamal-library.firebasestorage.app';
const PAGE_SIZE         = 'A4';
const STOCK             = 0;
const DRY_RUN           = process.argv.includes('--dry-run');
const CONCURRENCY       = (() => {
  const m = process.argv.find(a => a.startsWith('--concurrency='));
  return m ? parseInt(m.split('=')[1]) : 8;
})();
// ────────────────────────────────────────────────────────────

const admin = require('../functions/node_modules/firebase-admin');
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  storageBucket: STORAGE_BUCKET,
  projectId: FIREBASE_PROJECT,
});
const db     = admin.firestore();
const bucket = admin.storage().bucket();

// ── تطبيع أسماء الكليات ─────────────────────────────────────
function normalizeCollege(raw) {
  const s = raw.trim();
  if (/بشري/i.test(s))                    return 'كلية الطب';
  if (/صيدل/i.test(s))                    return 'كلية الصيدلة';
  if (/اسنان|أسنان|الاسنان/i.test(s))    return 'كلية طب الأسنان';
  if (/تحضيري/i.test(s))                 return 'السنة التحضيرية';
  return s;
}

// ── تطبيع الفصل ─────────────────────────────────────────────
function normalizeSemester(raw) {
  if (/اول|أول/i.test(raw))              return 'الفصل الأول';
  if (/ثاني|تاني/i.test(raw))            return 'الفصل الثاني';
  return raw;
}

// ── مجلدات تُستثنى من الاستيراد (ليست سنوات دراسية) ─────────
const EXCLUDED_YEAR_FOLDERS = [
  'كتب', 'وطني', 'حكيم', 'ملخص', 'مجلد', 'extra', 'اكسترا', 'prex', 'elite', 'medex', 'rbcs',
];
function isValidYearFolder(raw, college) {
  if (college === 'السنة التحضيرية') return true;
  const s = raw.trim().toLowerCase();
  if (EXCLUDED_YEAR_FOLDERS.some(ex => s.includes(ex))) return false;
  // يجب أن يحتوي على رقم أو كلمة سنة
  return /\d/.test(s) || /ثانية|ثالثة|رابعة|خامسة|تانية|تالتة|اولى|أولى/.test(s);
}

// ── تطبيع السنة الدراسية ────────────────────────────────────
const ARABIC_YEARS = {
  'أولى':'السنة الأولى','اولى':'السنة الأولى',
  'ثانية':'السنة الثانية','تانية':'السنة الثانية',
  'ثالثة':'السنة الثالثة','تالتة':'السنة الثالثة','تالثة':'السنة الثالثة',
  'رابعة':'السنة الرابعة',
  'خامسة':'السنة الخامسة',
};
const NUMBER_YEARS = ['','السنة الأولى','السنة الثانية','السنة الثالثة','السنة الرابعة','السنة الخامسة'];

function normalizeYear(raw) {
  const s = raw.trim();
  // رقم مباشر: "2", "3", "س2", "سنة 3", "اسنان س4"
  const num = s.match(/(\d)/);
  if (num) {
    const n = parseInt(num[1]);
    if (n >= 1 && n <= 5) return NUMBER_YEARS[n];
  }
  // كلمات عربية
  for (const [key, val] of Object.entries(ARABIC_YEARS)) {
    if (s.includes(key)) return val;
  }
  return s;
}

// ── عدد الصفحات ─────────────────────────────────────────────
function getPageCount(pdfPath) {
  try {
    const out = execSync(`pdfinfo "${pdfPath}" 2>/dev/null`, { encoding: 'utf8' });
    const m = out.match(/Pages:\s+(\d+)/);
    return m ? parseInt(m[1]) : 1;
  } catch { return 1; }
}

// ── رقم المحاضرة من اسم الملف ──────────────────────────────
function parseLectureNumber(filename) {
  const base = path.basename(filename, path.extname(filename)).trim();
  const m = base.match(/^(\d+)/);
  if (m) return parseInt(m[1]);
  const m2 = base.match(/(\d+)/);
  if (m2) return parseInt(m2[1]);
  return 0;
}

// ── استخراج الصفحة الأولى كصورة ────────────────────────────
function extractFirstPage(pdfPath) {
  const tmp = `/tmp/preview_${Date.now()}_${Math.random().toString(36).slice(2)}.png`;
  try {
    execSync(`pdftoppm -r 120 -f 1 -l 1 -png "${pdfPath}" "${tmp.replace('.png','')}" 2>/dev/null`);
    const actual = tmp.replace('.png', '-1.png');
    if (fs.existsSync(actual)) return actual;
    // fallback: pdftoppm might output differently
    const files = fs.readdirSync('/tmp').filter(f => f.startsWith(path.basename(tmp.replace('.png',''))));
    if (files.length > 0) return `/tmp/${files[0]}`;
  } catch {}
  return null;
}

// ── رفع الصورة ─────────────────────────────────────────────
async function uploadPreview(imgPath, lectureId) {
  const dest = `lectures/${lectureId}.png`;
  const token = lectureId;
  await bucket.upload(imgPath, {
    destination: dest,
    metadata: {
      contentType: 'image/png',
      metadata: { firebaseStorageDownloadTokens: token },
    },
  });
  const encoded = encodeURIComponent(dest);
  return `https://firebasestorage.googleapis.com/v0/b/${STORAGE_BUCKET}/o/${encoded}?alt=media&token=${token}`;
}

// ── جمع كل ملفات PDF ───────────────────────────────────────
function collectPdfs(dir, depth = 0, meta = {}) {
  const results = [];
  let entries;
  try { entries = fs.readdirSync(dir); } catch { return results; }

  for (const entry of entries) {
    const fullPath = path.join(dir, entry);
    let stat;
    try { stat = fs.statSync(fullPath); } catch { continue; }

    if (stat.isDirectory()) {
      const newMeta = { ...meta };
      // depth 0 = year folder, 1 = semester, 2 = college, 3 = year_level or subject (for تحضيري)
      if (depth === 0) {
        newMeta.archiveSection = `أرشيف ${entry}`;
      } else if (depth === 1) {
        newMeta.semester = normalizeSemester(entry);
      } else if (depth === 2) {
        newMeta.college = normalizeCollege(entry);
        if (newMeta.college === 'السنة التحضيرية') {
          newMeta.year = 'السنة التحضيرية';
          newMeta.subjectParts = [];
          newMeta.isPrepYear = true;
        }
      } else if (depth === 3) {
        if (meta.isPrepYear) {
          newMeta.subjectParts = [entry];
        } else {
          if (!isValidYearFolder(entry, meta.college)) continue;
          newMeta.year = normalizeYear(entry);
          newMeta.subjectParts = [];
        }
      } else {
        // depth 4+: subject or sub-subject
        newMeta.subjectParts = [...(meta.subjectParts || []), entry];
      }
      results.push(...collectPdfs(fullPath, depth + 1, newMeta));
    } else if (/\.pdf$/i.test(entry)) {
      if (!meta.college || !meta.year || !meta.semester || !meta.archiveSection) continue;
      const subjectParts = meta.subjectParts || [];
      if (subjectParts.length === 0) continue; // no subject = skip

      const subject = subjectParts.join(' — ');
      const lectureNum = parseLectureNumber(entry);
      results.push({
        pdfPath: fullPath,
        archiveSection: meta.archiveSection,
        semester: meta.semester,
        college: meta.college,
        year: meta.year,
        subject,
        lectureNumber: lectureNum,
      });
    }
  }
  return results;
}

// ── معالجة دفعة بالتوازي ───────────────────────────────────
async function processInBatches(items, batchSize, fn) {
  const results = [];
  for (let i = 0; i < items.length; i += batchSize) {
    const batch = items.slice(i, i + batchSize);
    const r = await Promise.allSettled(batch.map(fn));
    results.push(...r);
    console.log(`تقدم: ${Math.min(i + batchSize, items.length)} / ${items.length}`);
  }
  return results;
}

// ── رفع محاضرة واحدة ───────────────────────────────────────
async function importLecture(item) {
  const { pdfPath, archiveSection, semester, college, year, subject, lectureNumber } = item;

  const pages = getPageCount(pdfPath);
  const lectureId = `${Date.now()}_${Math.random().toString(36).slice(2)}`;

  let previewUrl = '';
  const imgPath = extractFirstPage(pdfPath);
  if (imgPath) {
    try {
      previewUrl = await uploadPreview(imgPath, lectureId);
    } finally {
      try { fs.unlinkSync(imgPath); } catch {}
    }
  }

  await db.collection('lectures').doc(lectureId).set({
    category: college,
    year,
    semester,
    archiveSection,
    subject,
    title: `محاضرة ${lectureNumber}`,
    lectureNumber,
    doctorName: '',
    pages,
    pageSize: PAGE_SIZE,
    stock: STOCK,
    available: true,
    previewImageUrl: previewUrl,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return `✓ ${college} | ${year} | ${subject} | محاضرة ${lectureNumber}`;
}

// ── main ────────────────────────────────────────────────────
async function main() {
  console.log('🔍 جاري مسح مجلد akp...');
  const allPdfs = collectPdfs(ROOT);
  console.log(`وجدت ${allPdfs.length} ملف PDF`);

  if (DRY_RUN) {
    // عرض ملخص بدون رفع
    const summary = {};
    for (const item of allPdfs) {
      const key = `${item.college} | ${item.year} | ${item.archiveSection} | ${item.semester}`;
      summary[key] = (summary[key] || 0) + 1;
    }
    console.log('\nملخص (dry-run):');
    for (const [k, v] of Object.entries(summary)) {
      console.log(`  ${k}: ${v} محاضرة`);
    }
    console.log('\nلبدء الرفع الفعلي: node scripts/import_all.js');
    process.exit(0);
  }

  console.log(`\n🚀 بدء الرفع بتوازي ${CONCURRENCY}...`);
  const results = await processInBatches(allPdfs, CONCURRENCY, importLecture);
  const ok = results.filter(r => r.status === 'fulfilled').length;
  const fail = results.filter(r => r.status === 'rejected');
  console.log(`\n✅ تم رفع ${ok} / ${allPdfs.length} محاضرة`);
  if (fail.length > 0) {
    console.log(`❌ فشل ${fail.length}:`);
    fail.slice(0, 10).forEach(f => console.log(' -', f.reason?.message));
  }
  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });
