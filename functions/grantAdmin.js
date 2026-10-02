/**
 * سكريبت لمرة واحدة — منح صلاحية الأدمن لمستخدم معين.
 *
 * طريقة الاستخدام:
 *   1. حمّل ملف Service Account من Firebase Console:
 *      Project Settings > Service accounts > Generate new private key
 *   2. احفظه باسم `serviceAccount.json` بجوار هذا الملف (لا ترفعه لـ git)
 *   3. شغّل: node grantAdmin.js <UID>
 *
 *   مثال: node grantAdmin.js abc123xyz
 *
 *   احصل على الـ UID من Firebase Console > Authentication > Users
 */

const admin = require('firebase-admin');

const uid = process.argv[2];
if (!uid) {
  console.error('الاستخدام: node grantAdmin.js <UID>');
  process.exit(1);
}

let serviceAccount;
try {
  serviceAccount = require('./serviceAccount.json');
} catch (_) {
  console.error('لم يتم العثور على serviceAccount.json — راجع التعليمات في أعلى الملف');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

admin.auth().setCustomUserClaims(uid, { admin: true })
  .then(() => {
    console.log(`✅ تم منح صلاحية الأدمن للمستخدم: ${uid}`);
    console.log('على المستخدم تسجيل الخروج والدخول مجدداً لتفعيل الصلاحية.');
    process.exit(0);
  })
  .catch((err) => {
    console.error('فشل:', err.message);
    process.exit(1);
  });
