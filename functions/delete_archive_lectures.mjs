import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

initializeApp({
  credential: applicationDefault(),
  projectId: 'alkamal-library',
  storageBucket: 'alkamal-library.firebasestorage.app',
});
const db = getFirestore();

async function deleteByArchive(archiveSection) {
  let total = 0;
  while (true) {
    const snap = await db.collection('lectures')
      .where('archiveSection', '==', archiveSection)
      .limit(400)
      .get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(d => batch.delete(d.ref));
    await batch.commit();
    total += snap.size;
    console.log(`  Deleted ${total} from "${archiveSection}"...`);
  }
  return total;
}

async function main() {
  console.log('🗑️  Deleting old archive lectures...');
  const a = await deleteByArchive('أرشيف 2023-2024');
  const b = await deleteByArchive('أرشيف 2024-2025');
  console.log(`✅ Done: ${a + b} lectures deleted`);
}

main().catch(console.error);
