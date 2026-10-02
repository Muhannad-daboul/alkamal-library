/**
 * سكريبت استيراد المحاضرات من مجلد محلي إلى Firebase
 * الاستخدام: node import_lectures.js
 */
const { execSync, spawnSync } = require('child_process');
const fs   = require('fs');
const path = require('path');
const os   = require('os');

// ─── إعدادات ────────────────────────────────────────────────
const ROOT_FOLDER   = '/Users/muhannaddaboul/Downloads/اسنان س2';
const COLLEGE       = 'طب الأسنان';
const YEAR          = 'سنة 2';
const SEMESTER      = 'الفصل الأول';       // ← غيّر إذا لزم
const ARCHIVE_SEC   = 'السنة الحالية';     // أو 'أرشيف 2024-2025'
const PAGE_SIZE     = 'A4';
const STOCK         = 0;
const FIREBASE_PROJECT = 'alkamal-library';
const STORAGE_BUCKET   = 'alkamal-library.firebasestorage.app';
// ────────────────────────────────────────────────────────────

const admin = require('./node_modules/firebase-admin');

// نستخدم Application Default Credentials (gcloud)
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  storageBucket: STORAGE_BUCKET,
  projectId: FIREBASE_PROJECT,
});

const db     = admin.firestore();
const bucket = admin.storage().bucket();

// ── استخراج عدد الصفحات ─────────────────────────────────────
function getPageCount(pdfPath) {
  try {
    const out = execSync(`pdfinfo "${pdfPath}" 2>/dev/null`, { encoding: 'utf8' });
    const m = out.match(/Pages:\s+(\d+)/);
    return m ? parseInt(m[1]) : 0;
  } catch { return 0; }
}

// ── استخراج رقم المحاضرة من اسم الملف ─────────────────────
function parseLectureNumber(filename) {
  const base = path.basename(filename, '.pdf').trim();
  // تعامل مع حالات: "1", "1a", "1b", "3+4", "ex1", "سنية5"
  const m = base.match(/^(\d+)/);
  if (m) return parseInt(m[1]);
  const m2 = base.match(/(\d+)/);
  if (m2) return parseInt(m2[1]);
  return 0;
}

// ── عنوان المحاضرة ──────────────────────────────────────────
function buildTitle(subjectName, filename) {
  const base = path.basename(filename, '.pdf').trim();
  return `محاضرة ${base} — ${subjectName}`;
}

// ── استخراج الصفحة الأولى كصورة ────────────────────────────
function extractCover(pdfPath) {
  const tmpDir  = fs.mkdtempSync(path.join(os.tmpdir(), 'lecture_cover_'));
  const outBase = path.join(tmpDir, 'cover');
  const result  = spawnSync(
    'pdftoppm',
    ['-f', '1', '-l', '1', '-r', '120', '-jpeg', pdfPath, outBase],
  );
  if (result.error) { fs.rmSync(tmpDir, { recursive: true }); return null; }
  // pdftoppm ينشئ cover-1.jpg أو cover-01.jpg
  const files = fs.readdirSync(tmpDir);
  if (files.length === 0) { fs.rmSync(tmpDir, { recursive: true }); return null; }
  return { filePath: path.join(tmpDir, files[0]), tmpDir };
}

// ── رفع الغلاف على Firebase Storage ────────────────────────
async function uploadCover(localPath, storagePath) {
  await bucket.upload(localPath, {
    destination: storagePath,
    metadata: { contentType: 'image/jpeg' },
  });
  const file = bucket.file(storagePath);
  await file.makePublic();
  return `https://storage.googleapis.com/${STORAGE_BUCKET}/${storagePath}`;
}

// ── المعالجة الرئيسية ────────────────────────────────────────
async function main() {
  console.log(`\n📂 البدء بمعالجة: ${ROOT_FOLDER}\n`);

  // اقرأ المجلدات الفرعية (المواد)
  const entries = fs.readdirSync(ROOT_FOLDER, { withFileTypes: true });
  const subjects = entries.filter(e => e.isDirectory()).map(e => e.name);

  let totalUploaded = 0;
  let totalSkipped  = 0;

  for (const subject of subjects) {
    const subjectPath = path.join(ROOT_FOLDER, subject);
    const pdfFiles = fs.readdirSync(subjectPath)
      .filter(f => f.toLowerCase().endsWith('.pdf'))
      .sort();

    console.log(`\n📚 المادة: ${subject} (${pdfFiles.length} ملفات)`);

    for (const pdfFile of pdfFiles) {
      const pdfPath = path.join(subjectPath, pdfFile);
      const storageCoverPath = `lecture_covers/${COLLEGE}/${YEAR}/${subject}/${path.basename(pdfFile, '.pdf')}.jpg`;

      process.stdout.write(`  ⏳ ${pdfFile} ... `);

      // استخراج الغلاف
      const cover = extractCover(pdfPath);
      if (!cover) {
        console.log('❌ فشل استخراج الغلاف');
        totalSkipped++;
        continue;
      }

      let previewUrl = '';
      try {
        previewUrl = await uploadCover(cover.filePath, storageCoverPath);
      } catch (err) {
        console.log(`❌ فشل الرفع: ${err.message}`);
        fs.rmSync(cover.tmpDir, { recursive: true });
        totalSkipped++;
        continue;
      }
      fs.rmSync(cover.tmpDir, { recursive: true });

      const pages   = getPageCount(pdfPath);
      const lectNum = parseLectureNumber(pdfFile);
      const title   = buildTitle(subject, pdfFile);

      // إنشاء سجل Firestore
      await db.collection('lectures').add({
        category:        subject,
        year:            YEAR,
        semester:        SEMESTER,
        archiveSection:  ARCHIVE_SEC,
        title:           title,
        lectureNumber:   lectNum,
        doctorName:      '',
        pages:           pages,
        pageSize:        PAGE_SIZE,
        stock:           STOCK,
        available:       true,
        previewImageUrl: previewUrl,
        customPrice:     null,
        college:         COLLEGE,
        createdAt:       admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`✅ (${pages} صفحة)`);
      totalUploaded++;
    }
  }

  console.log(`\n✅ انتهى! رُفع ${totalUploaded} محاضرة — تجاوز ${totalSkipped}\n`);
  process.exit(0);
}

main().catch(err => {
  console.error('خطأ:', err);
  process.exit(1);
});
