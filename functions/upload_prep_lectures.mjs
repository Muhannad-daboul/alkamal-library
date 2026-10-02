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
const TMP_DIR  = join(os.tmpdir(), 'prep_previews');
mkdirSync(TMP_DIR, { recursive: true });

const SOURCES = ['elite', 'medex', 'prex', 'rbcs'];

function parseArchiveSection(yearFolder) {
  if (yearFolder.includes('2023-2024')) return 'أرشيف 2023-2024';
  if (yearFolder.includes('2024-2025')) return 'أرشيف 2024-2025';
  return yearFolder;
}

function parseSemester(semFolder) {
  const f = semFolder.replace(/\s+/g, '');
  if (f.includes('فصلاول') || f.includes('فصل1')) return 'الفصل الأول';
  if (f.includes('فصلثاني') || f.includes('فصلتاني') || f.includes('فصل2')) return 'الفصل الثاني';
  return 'الفصل الأول';
}

function parseLectureInfo(filename) {
  const base = basename(filename, extname(filename)).trim();
  if (/^\d+$/.test(base)) return { lectureNumber: parseInt(base), title: '' };
  const mLetter = base.match(/^(\d+)([A-Za-z])$/);
  if (mLetter) return { lectureNumber: parseInt(mLetter[1]), title: mLetter[2].toUpperCase() };
  const mPlus = base.match(/^(\d+)\+(\d+)$/);
  if (mPlus) return { lectureNumber: parseInt(mPlus[1]), title: `+${mPlus[2]}` };
  const numMatch = base.match(/(\d+)/);
  if (numMatch) return { lectureNumber: parseInt(numMatch[1]), title: '' };
  return null;
}

function countPages(p) {
  try {
    const out = execSync(`"${PDFINFO}" "${p}" 2>/dev/null`, { encoding: 'utf8' });
    const m = out.match(/Pages:\s*(\d+)/);
    return m ? parseInt(m[1]) : 0;
  } catch { return 0; }
}

function extractFirstPage(pdfPath, outBase) {
  try {
    spawnSync(PDFTOPPM, ['-f','1','-l','1','-jpeg','-r','150', pdfPath, outBase]);
    for (const c of [`${outBase}-1.jpg`, `${outBase}-01.jpg`, `${outBase}-001.jpg`]) {
      try { statSync(c); return c; } catch {}
    }
    return null;
  } catch { return null; }
}

async function lectureExists(archive, semester, subject, lectureNumber) {
  const snap = await db.collection('lectures')
    .where('category', '==', 'السنة التحضيرية')
    .where('year', '==', 'السنة التحضيرية')
    .where('semester', '==', semester)
    .where('archiveSection', '==', archive)
    .where('subject', '==', subject)
    .where('lectureNumber', '==', lectureNumber)
    .limit(1)
    .get();
  return !snap.empty;
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

function* walkPrep(root) {
  for (const yearFolder of readdirSync(root)) {
    const yearPath = join(root, yearFolder);
    if (!statSync(yearPath).isDirectory()) continue;
    const archive = parseArchiveSection(yearFolder);

    for (const semFolder of readdirSync(yearPath)) {
      const semPath = join(yearPath, semFolder);
      if (!statSync(semPath).isDirectory()) continue;
      const semester = parseSemester(semFolder);

      const prepPath = join(semPath, 'تحضيري');
      try { if (!statSync(prepPath).isDirectory()) continue; } catch { continue; }

      for (const source of readdirSync(prepPath)) {
        if (!SOURCES.includes(source.toLowerCase())) continue;
        const sourcePath = join(prepPath, source);
        if (!statSync(sourcePath).isDirectory()) continue;

        for (const subjectFolder of readdirSync(sourcePath)) {
          const subjectPath = join(sourcePath, subjectFolder);
          if (!statSync(subjectPath).isDirectory()) continue;

          for (const file of readdirSync(subjectPath)) {
            if (extname(file).toLowerCase() !== '.pdf') continue;
            const info = parseLectureInfo(file);
            if (!info) continue;

            yield {
              pdfPath: join(subjectPath, file),
              archive,
              semester,
              subject: `${subjectFolder.trim()} - ${source.toLowerCase()}`,
              lectureNumber: info.lectureNumber,
              title: info.title,
            };
          }
        }
      }
    }
  }
}

async function main() {
  const lectures = [...walkPrep(AKP_ROOT)];
  console.log(`📚 Found ${lectures.length} prep lectures`);

  let uploaded = 0, skipped = 0, errors = 0;
  for (let i = 0; i < lectures.length; i++) {
    const lec = lectures[i];
    const tag = `[${i+1}/${lectures.length}]`;
    try {
      if (await lectureExists(lec.archive, lec.semester, lec.subject, lec.lectureNumber)) {
        console.log(`⏭ ${tag} SKIP: ${lec.subject} #${lec.lectureNumber}`);
        skipped++;
        continue;
      }

      const pages = countPages(lec.pdfPath);
      const tmpBase = join(TMP_DIR, `prep_${Date.now()}_${i}`);
      const imgPath = extractFirstPage(lec.pdfPath, tmpBase);
      if (!imgPath) { console.log(`⚠️ ${tag} No preview: ${lec.subject} #${lec.lectureNumber}`); errors++; continue; }

      const docRef = db.collection('lectures').doc();
      const url = await uploadImage(imgPath, `lectures/${docRef.id}.jpg`);
      try { rmSync(imgPath); } catch {}

      await docRef.set({
        id: docRef.id,
        archiveSection: lec.archive,
        semester: lec.semester,
        category: 'السنة التحضيرية',
        year: 'السنة التحضيرية',
        subject: lec.subject,
        lectureNumber: lec.lectureNumber,
        title: lec.title,
        doctorName: '',
        pages,
        pageSize: 'A4',
        customPrice: null,
        available: true,
        previewImageUrl: url,
        stock: 0,
        createdAt: new Date(),
      });

      console.log(`✅ ${tag} ${lec.archive} | ${lec.semester} | ${lec.subject} #${lec.lectureNumber} (${pages}p)`);
      uploaded++;
    } catch (e) {
      console.log(`❌ ${tag} ${lec.subject} #${lec.lectureNumber}: ${e.message}`);
      errors++;
    }
  }
  console.log(`\n📊 Done: ${uploaded} uploaded, ${skipped} skipped, ${errors} errors`);
  process.exit(0);
}

main().catch(console.error);
