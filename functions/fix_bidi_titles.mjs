import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

initializeApp({
  credential: applicationDefault(),
  projectId: 'alkamal-library',
});
const db = getFirestore();

// Strip all Unicode bidi control characters
function cleanTitle(title) {
  return title
    .replace(/[‪-‮⁦-⁩‎‏؜﻿]/g, '')
    .trim();
}

async function main() {
  let lastDoc = null;
  let fixed = 0, skipped = 0, total = 0;

  while (true) {
    let query = db.collection('lectures').orderBy('__name__').limit(400);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snap = await query.get();
    if (snap.empty) break;
    lastDoc = snap.docs[snap.docs.length - 1];
    total += snap.size;

    const batch = db.batch();
    let batchHasUpdates = false;

    for (const doc of snap.docs) {
      const title = doc.data().title ?? '';
      const cleaned = cleanTitle(title);
      if (cleaned !== title) {
        batch.update(doc.ref, { title: cleaned });
        batchHasUpdates = true;
        fixed++;
        console.log(`FIX: "${title}" → "${cleaned}"`);
      } else {
        skipped++;
      }
    }

    if (batchHasUpdates) await batch.commit();
    process.stdout.write(`\rProcessed ${total}...`);
  }

  console.log(`\n✅ Done: ${fixed} fixed, ${skipped} unchanged`);
}

main().catch(console.error);
