import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

initializeApp({ credential: applicationDefault(), storageBucket: 'alkamal-library.appspot.com' });
const db = getFirestore();
const snap = await db.collection('lectures').limit(1).get();
console.log('Firebase OK, docs:', snap.size);
process.exit(0);
