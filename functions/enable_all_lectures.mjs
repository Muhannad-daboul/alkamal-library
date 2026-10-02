import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

initializeApp({
  credential: applicationDefault(),
  projectId: 'alkamal-library',
  storageBucket: 'alkamal-library.firebasestorage.app',
});
const db = getFirestore();

let updated = 0;
let cursor = null;

while (true) {
  let q = db.collection('lectures').where('available', '==', false).limit(400);
  if (cursor) q = q.startAfter(cursor);
  const snap = await q.get();
  if (snap.empty) break;

  const batch = db.batch();
  for (const doc of snap.docs) {
    batch.update(doc.ref, { available: true });
  }
  await batch.commit();
  updated += snap.size;
  cursor = snap.docs[snap.docs.length - 1];
  console.log(`✅ Updated ${updated} so far...`);
  if (snap.size < 400) break;
}

console.log(`\n🎉 Done — ${updated} lectures enabled.`);
process.exit(0);
