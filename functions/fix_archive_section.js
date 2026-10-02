/**
 * يحدّث archiveSection من 'السنة الحالية' إلى 'أرشيف 2024-2025'
 * الاستخدام: node fix_archive_section.js
 */
const admin = require('./node_modules/firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'alkamal-library',
});

const db = admin.firestore();

async function fix() {
  const snap = await db.collection('lectures')
    .where('archiveSection', '==', 'السنة الحالية')
    .where('category', '==', 'كلية طب الأسنان')
    .get();

  if (snap.empty) {
    console.log('لا توجد وثائق بحاجة للتحديث');
    return;
  }

  console.log(`سيتم تحديث ${snap.size} وثيقة...`);

  const batches = [];
  let batch = db.batch();
  let count = 0;

  for (const doc of snap.docs) {
    batch.update(doc.ref, { archiveSection: 'أرشيف 2024-2025' });
    count++;
    if (count % 400 === 0) {
      batches.push(batch.commit());
      batch = db.batch();
    }
  }
  batches.push(batch.commit());

  await Promise.all(batches);
  console.log(`✅ تم تحديث ${snap.size} وثيقة إلى 'أرشيف 2024-2025'`);
}

fix().catch(console.error).finally(() => process.exit(0));
