import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { execSync, spawnSync } from 'child_process';
import { readdirSync, statSync, mkdirSync, rmSync } from 'fs';
import { join, basename, extname } from 'path';
import os from 'os';

initializeApp({
  credential: applicationDefault(),
  projectId: 'alkamal-library',
  storageBucket: 'alkamal-library.firebasestorage.app',
});
const db = getFirestore();
const bucket = getStorage().bucket();

const AKP_ROOT = '/Users/muhannaddaboul/Desktop/akp';
const PDFTOPPM = '/opt/homebrew/bin/pdftoppm';
const PDFINFO  = '/opt/homebrew/bin/pdfinfo';
const TMP_DIR  = join(os.tmpdir(), 'named_lecture_previews');
mkdirSync(TMP_DIR, { recursive: true });

// ── Parsers ───────────────────────────────────────────────────────────
function parseArchiveSection(yearFolder) {
  if (yearFolder.includes('2023-2024') || yearFolder.includes('2024-2023')) return 'أرشيف 2023-2024';
  if (yearFolder.includes('2024-2025') || yearFolder.includes('2025-2024')) return 'أرشيف 2024-2025';
  return yearFolder;
}

function parseSemester(semFolder) {
  const f = semFolder.replace(/\s+/g, '');
  if (/فصلاول|فصل1/.test(f))           return 'الفصل الأول';
  if (/فصلثاني|فصلتاني|فصل2/.test(f)) return 'الفصل الثاني';
  return 'الفصل الأول';
}

function parseCategory(facultyFolder) {
  const f = facultyFolder.trim();
  if (/اسنان|أسنان|الاسنان/i.test(f)) return 'كلية طب الأسنان';
  if (/بشري/i.test(f))                 return 'كلية الطب البشري';
  if (/صيدلة/i.test(f))                return 'كلية الصيدلة';
  if (/تحضيري/i.test(f))              return 'السنة التحضيرية';
  return null;
}

function parseYear(segment) {
  const f = segment.replace(/\s+/g, '');
  if (/[2٢]|ثاني/.test(f)) return 'السنة الثانية';
  if (/[3٣]|ثالث/.test(f)) return 'السنة الثالثة';
  if (/[4٤]|رابع/.test(f)) return 'السنة الرابعة';
  if (/[5٥]|خامس/.test(f)) return 'السنة الخامسة';
  return null;
}

const SKIP_FILE_PATTERNS = [
  /نوطة|وطني|كتب|قصص|معدلة|تكرم/,
  /حكيم/i, /elite/i, /medex/i, /prex/i, /rbcs/i,
  /^ex/i, /watermark/i,
];

const SKIP_FOLDER_PATTERNS = [
  /نوطة|وطني|كتب|قصص|تكرم|عملي|حكيم/,
  /elite/i, /medex/i, /prex/i, /rbcs/i,
  /^4444$/, /اوراق/, /perfect/i,
];

function shouldSkip(name, isFolder) {
  const patterns = isFolder ? SKIP_FOLDER_PATTERNS : SKIP_FILE_PATTERNS;
  return patterns.some(p => p.test(name));
}

// ── Collect all PDFs ──────────────────────────────────────────────────
function collectPdfs(root) {
  const results = [];

  function walk(dir, depth, ctx) {
    let entries;
    try { entries = readdirSync(dir); } catch { return; }

    for (const entry of entries) {
      const fullPath = join(dir, entry);
      let stat;
      try { stat = statSync(fullPath); } catch { continue; }

      if (stat.isDirectory()) {
        if (shouldSkip(entry, true)) continue;
        const newCtx = { ...ctx };

        // depth 0 = year, 1 = semester, 2 = faculty, 3+ = year/subject
        if (depth === 0) newCtx.archiveSection = parseArchiveSection(entry);
        else if (depth === 1) newCtx.semester = parseSemester(entry);
        else if (depth === 2) {
          newCtx.category = parseCategory(entry);
          if (!newCtx.category) continue; // unknown faculty
        } else {
          const yr = parseYear(entry);
          if (yr) newCtx.year = yr;
          else if (!newCtx.subject) newCtx.subject = entry.trim();
          else newCtx.subject = entry.trim(); // deeper folder overrides subject
        }

        walk(fullPath, depth + 1, newCtx);
      } else if (extname(entry).toLowerCase() === '.pdf') {
        if (shouldSkip(entry, false)) continue;
        if (!ctx.category) continue;

        const title = basename(entry, extname(entry)).trim();
        if (!title) continue;

        // For تحضيري, year is not required
        const year = ctx.year || (ctx.category === 'السنة التحضيرية' ? 'السنة التحضيرية' : '');
        if (!year) continue;

        const subject = ctx.subject || ctx.category;

        results.push({
          pdfPath: fullPath,
          archiveSection: ctx.archiveSection || '',
          semester: ctx.semester || 'الفصل الأول',
          category: ctx.category,
          year,
          subject,
          title,
        });
      }
    }
  }

  walk(root, 0, {});
  return results;
}

// ── Utilities ─────────────────────────────────────────────────────────
function countPages(pdfPath) {
  try {
    const out = execSync(`"${PDFINFO}" "${pdfPath}" 2>/dev/null`, { encoding: 'utf8' });
    const m = out.match(/Pages:\s*(\d+)/);
    return m ? parseInt(m[1]) : 0;
  } catch { return 0; }
}

function extractFirstPage(pdfPath, outputBase) {
  try {
    spawnSync(PDFTOPPM, ['-f', '1', '-l', '1', '-jpeg', '-r', '150', pdfPath, outputBase]);
    for (const c of [`${outputBase}-1.jpg`, `${outputBase}-01.jpg`, `${outputBase}-001.jpg`]) {
      try { statSync(c); return c; } catch {}
    }
    return null;
  } catch { return null; }
}

async function uploadImage(localPath, storagePath) {
  await bucket.upload(localPath, {
    destination: storagePath,
    metadata: { contentType: 'image/jpeg' },
  });
  const file = bucket.file(storagePath);
  await file.makePublic();
  return `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
}

// ── Duplicate check by title + subject + category + archiveSection ────
async function lectureExists(category, year, archiveSection, subject, title) {
  const snap = await db.collection('lectures')
    .where('category', '==', category)
    .where('year', '==', year)
    .where('archiveSection', '==', archiveSection)
    .where('subject', '==', subject)
    .where('title', '==', title)
    .limit(1)
    .get();
  return !snap.empty;
}

// ── Main ──────────────────────────────────────────────────────────────
async function main() {
  const pdfs = collectPdfs(AKP_ROOT);
  console.log(`📚 Found ${pdfs.length} PDFs to process`);

  // Assign sequential lectureNumber per (category+year+archiveSection+semester+subject) group
  const counters = {};
  for (const p of pdfs) {
    const key = `${p.category}|${p.year}|${p.archiveSection}|${p.semester}|${p.subject}`;
    counters[key] = (counters[key] || 0) + 1;
    p.lectureNumber = counters[key];
  }

  let uploaded = 0, skipped = 0, errors = 0;

  for (let i = 0; i < pdfs.length; i++) {
    const lec = pdfs[i];
    const pct = ((i + 1) / pdfs.length * 100).toFixed(1);
    const tag = `[${i + 1}/${pdfs.length} ${pct}%]`;

    try {
      const exists = await lectureExists(
        lec.category, lec.year, lec.archiveSection, lec.subject, lec.title,
      );
      if (exists) {
        process.stdout.write(`⏭  ${tag} SKIP: ${lec.subject} — ${lec.title}\n`);
        skipped++;
        continue;
      }

      const pages = countPages(lec.pdfPath);
      const tmpBase = join(TMP_DIR, `lec_${Date.now()}_${i}`);
      const imgPath = extractFirstPage(lec.pdfPath, tmpBase);

      if (!imgPath) {
        process.stdout.write(`⚠️  ${tag} No preview: ${lec.title}\n`);
        errors++;
        continue;
      }

      const docRef = db.collection('lectures').doc();
      const storagePath = `lectures/${docRef.id}.jpg`;
      const imageUrl = await uploadImage(imgPath, storagePath);
      try { rmSync(imgPath); } catch {}

      await docRef.set({
        id: docRef.id,
        archiveSection: lec.archiveSection,
        semester: lec.semester,
        category: lec.category,
        year: lec.year,
        subject: lec.subject,
        lectureNumber: lec.lectureNumber,
        title: lec.title,
        doctorName: '',
        pages,
        pageSize: 'A4',
        customPrice: null,
        available: true,
        previewImageUrl: imageUrl,
        stock: 0,
        createdAt: new Date(),
      });

      process.stdout.write(`✅ ${tag} ${lec.category} | ${lec.year} | ${lec.subject} | ${lec.title}\n`);
      uploaded++;
    } catch (err) {
      process.stdout.write(`❌ ${tag} ERROR: ${lec.title} — ${err.message}\n`);
      errors++;
    }
  }

  console.log(`\n🎉 Done: ${uploaded} uploaded, ${skipped} skipped, ${errors} errors`);
}

main().catch(console.error);
