import { initializeApp, cert, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { execSync, spawnSync } from 'child_process';
import { readdirSync, statSync, mkdirSync, readFileSync, rmSync } from 'fs';
import { join, basename, extname, dirname } from 'path';
import os from 'os';

// ── Init ──────────────────────────────────────────────────────────────
initializeApp({
  credential: applicationDefault(),
  projectId: 'alkamal-library',
  storageBucket: 'alkamal-library.firebasestorage.app',
});
const db = getFirestore();
const bucket = getStorage().bucket();

// ── Constants ─────────────────────────────────────────────────────────
const AKP_ROOT = '/Users/muhannaddaboul/Desktop/akp';
const PDFTOPPM = '/opt/homebrew/bin/pdftoppm';
const PDFINFO  = '/opt/homebrew/bin/pdfinfo';
const TMP_DIR  = join(os.tmpdir(), 'lecture_previews');
mkdirSync(TMP_DIR, { recursive: true });

// ── Mappings ──────────────────────────────────────────────────────────
function parseArchiveSection(yearFolder) {
  if (yearFolder.includes('2023-2024')) return 'أرشيف 2023-2024';
  if (yearFolder.includes('2024-2025')) return 'أرشيف 2024-2025';
  return yearFolder;
}

function parseSemester(semFolder) {
  const f = semFolder.replace(/\s+/g, '');
  if (f.includes('فصلاول') || f.includes('فصل1') || f.includes('فصلاول')) return 'الفصل الأول';
  if (f.includes('فصلثاني') || f.includes('فصلتاني') || f.includes('فصل2')) return 'الفصل الثاني';
  return 'الفصل الأول';
}

function parseCategory(facultyFolder) {
  const f = facultyFolder.trim();
  if (/اسنان|أسنان|الاسنان/i.test(f)) return 'كلية طب الأسنان';
  if (/بشري/i.test(f))                  return 'كلية الطب البشري';
  if (/صيدلة/i.test(f))                 return 'كلية الصيدلة';
  if (/تحضيري/i.test(f))               return 'السنة التحضيرية';
  return f;
}

function parseYear(yearSubFolder) {
  const f = yearSubFolder.replace(/\s+/g, '');
  if (/[سs][\s]?2|سنة[\s]?2|سنةتانية|ثانية|^2$/.test(f)) return 'السنة الثانية';
  if (/[سs][\s]?3|سنة[\s]?3|سنةتالتة|ثالثة|^3$/.test(f)) return 'السنة الثالثة';
  if (/[سs][\s]?4|سنة[\s]?4|سنةرابعة|رابعة|^4$/.test(f)) return 'السنة الرابعة';
  if (/[سs][\s]?5|سنة[\s]?5|سنةخامسة|خامسة|^5$/.test(f)) return 'السنة الخامسة';
  return null; // unknown year — skip
}

// ── Skip non-lecture files ────────────────────────────────────────────
const SKIP_PATTERNS = [
  /^ex/i, /^EX/i,
  /نوطة/, /وطني/, /كتب/, /قصص/, /معدلة/, /تكرم/,
  /حكيم/, /elite/i, /medex/i, /prex/i, /rbcs/i,
];

function shouldSkipFile(name) {
  return SKIP_PATTERNS.some(p => p.test(name));
}

// ── Skip non-year folders ─────────────────────────────────────────────
const SKIP_FOLDERS = [
  /كتب/, /وطني/, /قصص/, /تكرم/, /عملي/, /حكيم/,
  /elite/i, /medex/i, /prex/i, /rbcs/i, /4444/,
  /اوراق/, /نوط[\s]عملي/,
];

function shouldSkipFolder(name) {
  return SKIP_FOLDERS.some(p => p.test(name));
}

// ── Parse lecture number from filename ────────────────────────────────
function parseLectureInfo(filename) {
  const base = basename(filename, extname(filename)).trim();

  // Pure number: "1", "12"
  if (/^\d+$/.test(base)) {
    return { lectureNumber: parseInt(base), title: '' };
  }
  // Number + letter: "2A", "7b"
  if (/^(\d+)[A-Za-z]$/.test(base)) {
    const m = base.match(/^(\d+)([A-Za-z])$/);
    return { lectureNumber: parseInt(m[1]), title: m[2].toUpperCase() };
  }
  // Number + plus + number: "3+4", "11+12"
  if (/^(\d+)\+(\d+)$/.test(base)) {
    const m = base.match(/^(\d+)\+(\d+)$/);
    return { lectureNumber: parseInt(m[1]), title: `+${m[2]}` };
  }
  // Arabic text + number(s): "ثقافة 1 جمال 1"
  const numMatch = base.match(/(\d+)/);
  if (numMatch) {
    return { lectureNumber: parseInt(numMatch[1]), title: '' };
  }
  // No number found — skip
  return null;
}

// ── Count PDF pages ───────────────────────────────────────────────────
function countPages(pdfPath) {
  try {
    const out = execSync(`"${PDFINFO}" "${pdfPath}" 2>/dev/null`, { encoding: 'utf8' });
    const m = out.match(/Pages:\s*(\d+)/);
    return m ? parseInt(m[1]) : 0;
  } catch { return 0; }
}

// ── Extract first page as JPEG ────────────────────────────────────────
function extractFirstPage(pdfPath, outputBase) {
  try {
    spawnSync(PDFTOPPM, [
      '-f', '1', '-l', '1',
      '-jpeg', '-r', '150',
      pdfPath, outputBase,
    ]);
    // pdftoppm outputs outputBase-1.jpg (zero-padded)
    const candidates = [
      `${outputBase}-1.jpg`,
      `${outputBase}-01.jpg`,
      `${outputBase}-001.jpg`,
    ];
    for (const c of candidates) {
      try { statSync(c); return c; } catch {}
    }
    return null;
  } catch { return null; }
}

// ── Check if lecture already exists in Firestore ──────────────────────
async function lectureExists(category, year, semester, archiveSection, subject, lectureNumber) {
  const snap = await db.collection('lectures')
    .where('category', '==', category)
    .where('year', '==', year)
    .where('semester', '==', semester)
    .where('archiveSection', '==', archiveSection)
    .where('subject', '==', subject)
    .where('lectureNumber', '==', lectureNumber)
    .limit(1)
    .get();
  return !snap.empty;
}

// ── Upload image to Firebase Storage ─────────────────────────────────
async function uploadImage(localPath, storagePath) {
  await bucket.upload(localPath, {
    destination: storagePath,
    metadata: { contentType: 'image/jpeg' },
  });
  const file = bucket.file(storagePath);
  await file.makePublic();
  return `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
}

// ── Walk folder tree ──────────────────────────────────────────────────
function* walkLectures(root) {
  // root/yearFolder/semesterFolder/facultyFolder/yearSubFolder/subjectFolder/file.pdf
  for (const yearFolder of readdirSync(root)) {
    const yearPath = join(root, yearFolder);
    if (!statSync(yearPath).isDirectory()) continue;
    const archiveSection = parseArchiveSection(yearFolder);

    for (const semFolder of readdirSync(yearPath)) {
      const semPath = join(yearPath, semFolder);
      if (!statSync(semPath).isDirectory()) continue;
      const semester = parseSemester(semFolder);

      for (const facultyFolder of readdirSync(semPath)) {
        const facPath = join(semPath, facultyFolder);
        if (!statSync(facPath).isDirectory()) continue;
        if (shouldSkipFolder(facultyFolder)) continue;
        const category = parseCategory(facultyFolder);

        for (const yearSubFolder of readdirSync(facPath)) {
          const yearSubPath = join(facPath, yearSubFolder);
          if (!statSync(yearSubPath).isDirectory()) continue;
          if (shouldSkipFolder(yearSubFolder)) continue;
          const year = parseYear(yearSubFolder);
          if (!year) continue; // skip non-year folders

          for (const subjectFolder of readdirSync(yearSubPath)) {
            const subjectPath = join(yearSubPath, subjectFolder);
            if (!statSync(subjectPath).isDirectory()) continue;
            if (shouldSkipFolder(subjectFolder)) continue;

            for (const file of readdirSync(subjectPath)) {
              if (extname(file).toLowerCase() !== '.pdf') continue;
              if (shouldSkipFile(file)) continue;
              const info = parseLectureInfo(file);
              if (!info) continue;

              yield {
                pdfPath: join(subjectPath, file),
                archiveSection,
                semester,
                category,
                year,
                subject: subjectFolder.trim(),
                lectureNumber: info.lectureNumber,
                title: info.title,
              };
            }
          }
        }
      }
    }
  }
}

// ── Main ──────────────────────────────────────────────────────────────
async function main() {
  const lectures = [...walkLectures(AKP_ROOT)];
  console.log(`📚 Found ${lectures.length} lectures to process`);

  let uploaded = 0, skipped = 0, errors = 0;

  for (let i = 0; i < lectures.length; i++) {
    const lec = lectures[i];
    const pct = ((i + 1) / lectures.length * 100).toFixed(1);
    const tag = `[${i+1}/${lectures.length} ${pct}%]`;

    try {
      // Check duplicate
      const exists = await lectureExists(
        lec.category, lec.year, lec.semester,
        lec.archiveSection, lec.subject, lec.lectureNumber,
      );
      if (exists) {
        process.stdout.write(`⏭  ${tag} SKIP (exists): ${lec.subject} #${lec.lectureNumber}\n`);
        skipped++;
        continue;
      }

      // Count pages
      const pages = countPages(lec.pdfPath);

      // Extract first page
      const tmpBase = join(TMP_DIR, `lec_${Date.now()}`);
      const imgPath = extractFirstPage(lec.pdfPath, tmpBase);
      if (!imgPath) {
        process.stdout.write(`⚠️  ${tag} No preview: ${lec.subject} #${lec.lectureNumber}\n`);
        errors++;
        continue;
      }

      // Create Firestore doc reference to get ID
      const docRef = db.collection('lectures').doc();

      // Upload preview image
      const storagePath = `lectures/${docRef.id}.jpg`;
      const imageUrl = await uploadImage(imgPath, storagePath);

      // Clean up temp file
      try { rmSync(imgPath); } catch {}

      // Save to Firestore
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
        pages: pages,
        pageSize: 'A4',
        customPrice: null,
        available: true,
        previewImageUrl: imageUrl,
        stock: 0,
        createdAt: new Date(),
      });

      process.stdout.write(`✅ ${tag} ${lec.archiveSection} | ${lec.category} | ${lec.year} | ${lec.subject} #${lec.lectureNumber} (${pages}p)\n`);
      uploaded++;

    } catch (e) {
      process.stdout.write(`❌ ${tag} ERROR: ${lec.subject} #${lec.lectureNumber}: ${e.message}\n`);
      errors++;
    }
  }

  console.log(`\n📊 Done: ${uploaded} uploaded, ${skipped} skipped (exists), ${errors} errors`);
}

main().catch(console.error);
