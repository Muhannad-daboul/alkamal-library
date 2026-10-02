import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

initializeApp({ credential: applicationDefault(), projectId: 'alkamal-library' });
const db = getFirestore();

// Count "ال" (alef-lam) appearing at word starts — common in correct Arabic
function alLamAtWordStarts(text) {
  return (text.match(/(?:^|\s)ال/g) || []).length;
}

function fixTitle(title) {
  // Strip leading number/dash prefix: "4 ", "08 - ", "3A ", etc.
  const prefixMatch = title.match(/^([\d\s\-\.a-zA-Z\+،,]*)/);
  const prefix = prefixMatch ? prefixMatch[0] : '';
  const arabicPart = title.slice(prefix.length).trim();

  if (arabicPart.length < 4) return title; // too short to reliably detect

  const reversed = [...arabicPart].reverse().join('');
  const originalScore = alLamAtWordStarts(arabicPart);
  const reversedScore = alLamAtWordStarts(reversed);

  if (reversedScore > originalScore) {
    // Reversed version has more definite articles at word starts → fix it
    return (prefix + reversed).trim();
  }
  return title;
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
    let hasUpdates = false;

    for (const doc of snap.docs) {
      const title = doc.data().title ?? '';
      const cleaned = fixTitle(title);
      if (cleaned !== title) {
        batch.update(doc.ref, { title: cleaned });
        hasUpdates = true;
        fixed++;
        process.stdout.write(`FIX: "${title}" → "${cleaned}"\n`);
      } else {
        skipped++;
      }
    }

    if (hasUpdates) await batch.commit();
    process.stdout.write(`\rProcessed ${total}...`);
  }

  console.log(`\n✅ Done: ${fixed} fixed, ${skipped} unchanged`);
}

main().catch(console.error);
