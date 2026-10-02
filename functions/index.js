const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const crypto = require('crypto');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
const db = getFirestore();

// ── ملاحظة أمنية ────────────────────────────────────────────
// دالة claimAdmin حُذفت نهائياً (2026-07-14): كانت تمنح custom claims
// بسر ثابت تسرّب داخل APK الطالب الموزَّع. صلاحية الأدمن الآن تتم
// حصراً عبر admin_sessions في Firestore (انظر firestore.rules).

// ── إشعار المندوب عند طلب جديد ────────────────────────────
exports.notifyDeliveryOnNewOrder = onDocumentCreated('orders/{orderId}', async (event) => {
  const order = event.data.data();

  await getMessaging().send({
    topic: 'delivery',
    notification: {
      title: 'طلب جديد 🛒',
      body: `${order.userName} — ${order.total} ل.س`,
    },
    android: {
      notification: { sound: 'default', channelId: 'delivery_channel' },
    },
  });
});

// ── إشعار الطالب عند تغيير الحالة ─────────────────────────
exports.notifyStudentOnStatusChange = onDocumentUpdated('orders/{orderId}', async (event) => {
  const before = event.data.before.data();
  const after  = event.data.after.data();

  if (before.status === after.status) return;

  const token = after.fcmToken;
  if (!token) return;

  let title, body;

  if (after.status === 'تم القبول') {
    if (after.deliveryMethod === 'pickup' && after.pickupCode) {
      title = 'طلبك جاهز للاستلام 🎉';
      body  = `كود الاستلام: ${after.pickupCode} — أظهر هذا الكود للموظف عند استلام محاضراتك من المكتبة`;
    } else {
      title = 'تم قبول طلبك ✅';
      body  = 'طلبك قيد التجهيز وسيصل إليك قريباً';
    }
  } else if (after.status === 'في الطريق') {
    title = 'طلبك في الطريق 🚴';
    body  = 'المندوب توجّه إليك، يُرجى الاستعداد للاستلام';
  } else {
    return;
  }

  await getMessaging().send({
    token,
    notification: { title, body },
    android: {
      notification: { sound: 'default', channelId: 'order_channel' },
    },
  });
});

// ── ragChat + placeOrder ──────────────────────────────────

const SYSTEM_PROMPT = `أنت مساعد مكتبة الكمال الطبية الذكي. مهمتك مساعدة العملاء في:
- الاستفسار عن المنتجات والأسعار والتوفر
- متابعة حالة الطلبات
- معرفة سياسات المتجر وساعات العمل

قواعد:
- أجب دائماً بالعربية
- استخدم الأدوات المتاحة للحصول على معلومات دقيقة قبل الإجابة
- إذا لم تجد معلومة، اعتذر بأدب واقترح التواصل مع المتجر مباشرة
- كن مختصراً ومهذباً ومفيداً`;

const TOOLS = [
  {
    name: 'search_products',
    description: 'البحث في قائمة المنتجات والنوطات والمستلزمات الطبية المتاحة',
    input_schema: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'كلمة البحث' },
      },
      required: ['query'],
    },
  },
  {
    name: 'get_product_details',
    description: 'الحصول على تفاصيل منتج محدد بواسطة معرفه (ID)',
    input_schema: {
      type: 'object',
      properties: {
        product_id: { type: 'string', description: 'معرف المنتج' },
      },
      required: ['product_id'],
    },
  },
  {
    name: 'get_order_status',
    description: 'الاستفسار عن حالة طلب محدد بواسطة معرفه',
    input_schema: {
      type: 'object',
      properties: {
        order_id: { type: 'string', description: 'معرف الطلب' },
      },
      required: ['order_id'],
    },
  },
  {
    name: 'get_store_info',
    description: 'الحصول على معلومات المتجر: ساعات العمل والسياسات ومعلومات التواصل',
    input_schema: { type: 'object', properties: {} },
  },
];

async function _executeTool(name, input, callerUid) {

  if (name === 'search_products') {
    const q = (input.query || '').toLowerCase().trim();
    if (!q) return 'يرجى تقديم كلمة بحث';

    // نجلب كل المنتجات المتاحة - الفلترة في الذاكرة
    const [prodSnap, supplySnap] = await Promise.all([
      db.collection('products').where('available', '==', true).get(),
      db.collection('supply_products').where('available', '==', true).get(),
    ]);

    const matches = [];
    const matchDoc = (doc, type) => {
      const d = doc.data();
      const haystack =
        `${d.title || ''} ${d.description || ''} ${d.category || ''}`.toLowerCase();
      if (haystack.includes(q)) {
        matches.push({
          id: doc.id,
          title: d.title,
          price: d.price,
          category: d.category,
          type,
        });
      }
    };
    prodSnap.forEach((doc) => matchDoc(doc, 'نوطة'));
    supplySnap.forEach((doc) => matchDoc(doc, 'مستلزم طبي'));

    if (matches.length === 0) return 'لا توجد منتجات مطابقة لبحثك';

    // نرجع أول 10 + إجمالي للسياق
    return JSON.stringify({
      total: matches.length,
      shown: Math.min(matches.length, 10),
      results: matches.slice(0, 10),
    });
  }

  if (name === 'get_product_details') {
    let doc = await db.collection('products').doc(input.product_id).get();
    if (!doc.exists) doc = await db.collection('supply_products').doc(input.product_id).get();
    if (!doc.exists) return 'المنتج غير موجود';
    return JSON.stringify({ id: doc.id, ...doc.data() });
  }

  if (name === 'get_order_status') {
    const doc = await db.collection('orders').doc(input.order_id).get();
    if (!doc.exists) return 'الطلب غير موجود. تأكد من رقم الطلب';
    const d = doc.data();
    // فحص الملكية — العميل يستطيع الاستعلام عن طلباته فقط
    if (d.userId !== callerUid) {
      return 'هذا الطلب لا يخصك. تأكد من رقم الطلب';
    }
    return JSON.stringify({
      id: doc.id,
      status: d.status,
      total: d.total,
      userName: d.userName,
      createdAt: d.createdAt?.toDate?.()?.toISOString(),
    });
  }

  if (name === 'get_store_info') {
    const ref = db.collection('store_info').doc('main');
    const doc = await ref.get();
    if (!doc.exists) {
      const defaults = {
        hours: '8 صباحاً - 10 مساءً يومياً',
        policies: 'سياسة الإرجاع: 7 أيام من تاريخ الشراء للمنتجات غير المستخدمة',
        phone: 'تواصل عبر التطبيق',
        address: 'سوريا',
      };
      await ref.set(defaults).catch(() => {});
      return JSON.stringify(defaults);
    }
    return JSON.stringify(doc.data());
  }

  return 'أداة غير معروفة';
}

// ── Rate limiting بسيط في الذاكرة (per-instance) ──────────
const _rateLimitMap = new Map();
const _RATE_LIMIT_WINDOW_MS = 60 * 1000;
const _RATE_LIMIT_MAX = 15;

function _checkRateLimit(userId) {
  const now = Date.now();
  const entry = _rateLimitMap.get(userId) || { count: 0, windowStart: now };
  if (now - entry.windowStart > _RATE_LIMIT_WINDOW_MS) {
    entry.count = 0;
    entry.windowStart = now;
  }
  entry.count++;
  _rateLimitMap.set(userId, entry);
  return entry.count <= _RATE_LIMIT_MAX;
}

exports.ragChat = onCall(
  { secrets: ['ANTHROPIC_API_KEY'] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }
    const userId = request.auth.uid;
    const { message, history = [] } = request.data;
    if (!message) throw new HttpsError('invalid-argument', 'message is required');

    if (!_checkRateLimit(userId)) {
      throw new HttpsError(
        'resource-exhausted',
        'تجاوزت الحد المسموح من الرسائل. حاول لاحقاً.',
      );
    }

    const Anthropic = require('@anthropic-ai/sdk');
    const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

    const messages = [
      ...history.slice(-10),
      { role: 'user', content: message },
    ];

    let response = await client.messages.create({
      model: 'claude-sonnet-4-6',
      max_tokens: 2048,
      system: SYSTEM_PROMPT,
      tools: TOOLS,
      messages,
    });

    while (response.stop_reason === 'tool_use') {
      const toolBlocks = response.content.filter((b) => b.type === 'tool_use');
      const toolResults = await Promise.all(
        toolBlocks.map(async (tb) => ({
          type: 'tool_result',
          tool_use_id: tb.id,
          content: await _executeTool(tb.name, tb.input, userId),
        }))
      );

      messages.push({ role: 'assistant', content: response.content });
      messages.push({ role: 'user', content: toolResults });

      response = await client.messages.create({
        model: 'claude-sonnet-4-6',
        max_tokens: 2048,
        system: SYSTEM_PROMPT,
        tools: TOOLS,
        messages,
      });
    }

    const textBlock = response.content.find((b) => b.type === 'text');
    return { reply: textBlock?.text || 'عذراً، لم أتمكن من الإجابة' };
  },
);

// ── validatePromo: التحقق من كود خصم واحد دون كشف القائمة كاملة ──
// العميل لا يقرأ مجموعة promo_codes مباشرةً (القاعدة تمنعه)، بل يفحص
// كوداً واحداً عبر هذه الدالة — فلا يمكن حصاد كل الأكواد.
exports.validatePromo = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'يجب تسجيل الدخول');
  }
  const raw = request.data && request.data.code;
  if (typeof raw !== 'string' || raw.trim().length === 0) {
    return { valid: false };
  }
  const code = raw.trim().toUpperCase();
  const snap = await db.collection('promo_codes')
    .where('code', '==', code)
    .where('active', '==', true)
    .limit(1)
    .get();
  if (snap.empty) return { valid: false };

  const promo = snap.docs[0].data();
  const now = Date.now();
  if (promo.expiresAt && promo.expiresAt.toMillis && promo.expiresAt.toMillis() < now) {
    return { valid: false };
  }
  const used = Number(promo.usedCount || 0);
  const limit = Number(promo.usageLimit || 0);
  if (limit > 0 && used >= limit) return { valid: false };

  // نرجع فقط ما يلزم لعرض معاينة الخصم — لا نكشف بقية الحقول
  const isPercent = promo.type === 'percent' || promo.isPercent === true;
  return {
    valid: true,
    type: isPercent ? 'percent' : 'fixed',
    discount: Number(promo.discount || 0),
  };
});

// ── placeOrder: إنشاء طلب مع تحقق من الأسعار وكود الخصم على الخادم ──
exports.placeOrder = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'يجب تسجيل الدخول');
  }
  const uid = request.auth.uid;

  const {
    userName, phone, address, notes,
    items, deliveryLat, deliveryLng,
    fcmToken, promoCode,
    deliveryMethod = 'delivery', zone = '',
    paymentMethod = 'cash',
  } = request.data || {};

  const isPickup = deliveryMethod === 'pickup';

  // تحقق أساسي من المدخلات
  if (typeof userName !== 'string' || userName.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'الاسم مطلوب');
  }
  if (typeof phone !== 'string' || phone.trim().length < 8) {
    throw new HttpsError('invalid-argument', 'رقم الهاتف غير صحيح');
  }
  if (!Array.isArray(items) || items.length === 0) {
    throw new HttpsError('invalid-argument', 'السلة فارغة');
  }
  if (items.length > 100) {
    throw new HttpsError('invalid-argument', 'عدد الأصناف كبير جداً');
  }

  // جلب سعر الصفحة من Firestore (للنوطات)
  const pricingDoc = await db.collection('settings').doc('pricing').get();
  const pricePerPage = pricingDoc.exists
    ? (pricingDoc.data().pricePerPage || 100)
    : 100;

  // إعادة احتساب الإجمالي من بيانات Firestore الحقيقية
  let subtotal = 0;
  const verifiedItems = [];
  for (const it of items) {
    const id = String(it.id || '');
    const qty = parseInt(it.quantity, 10);
    const isSupply = Boolean(it.isSupply);
    const isLecture = Boolean(it.isLecture);
    const isPrintJob = Boolean(it.isPrintJob);
    if (!id || !Number.isFinite(qty) || qty <= 0 || qty > 99) {
      throw new HttpsError('invalid-argument', 'صنف غير صالح');
    }

    // طلبات الطباعة — لا يوجد منتج في Firestore. نعيد حساب السعر على
    // الخادم من settings/print_pricing بناءً على المعطيات، لا نثق بسعر العميل.
    if (isPrintJob) {
      const pages = parseInt(it.printPageCount, 10);
      const copies = parseInt(it.printCopies, 10) || 1;
      if (!Number.isFinite(pages) || pages <= 0 || pages > 5000) {
        throw new HttpsError('failed-precondition', 'عدد صفحات الطباعة غير صالح');
      }
      if (copies <= 0 || copies > 100) {
        throw new HttpsError('failed-precondition', 'عدد النسخ غير صالح');
      }
      const ppDoc = await db.collection('settings').doc('print_pricing').get();
      const pp = ppDoc.exists ? ppDoc.data() : {};
      const color = it.printColor === 'color' ? 'color' : 'bw';
      const sides = it.printSides === 'two' ? 'two' : 'one';
      const perPage = color === 'color'
        ? (sides === 'one' ? Number(pp.colorSinglePage ?? 100) : Number(pp.colorDoublePage ?? 80))
        : (sides === 'one' ? Number(pp.bwSinglePage ?? 25) : Number(pp.bwDoublePage ?? 20));
      let bindingFee = 0;
      if (it.printBinding === 'staple') bindingFee = Number(pp.bindingStaple ?? 500);
      else if (it.printBinding === 'spiral') bindingFee = Number(pp.bindingSpiral ?? 1500);
      const unitPrice = (pages * perPage + bindingFee) * copies;
      if (!Number.isFinite(unitPrice) || unitPrice <= 0) {
        throw new HttpsError('failed-precondition', 'سعر طلب الطباعة غير صالح');
      }
      const storagePath = typeof it.printJobStoragePath === 'string' ? it.printJobStoragePath : '';
      subtotal += unitPrice * qty;
      verifiedItems.push({
        title: String(it.title || 'طلب طباعة PDF'),
        price: unitPrice,
        quantity: qty,
        isSupply: false,
        isPrintJob: true,
        printJobStoragePath: storagePath,
        imageUrl: '',
      });
      continue;
    }

    // مواد كاملة (bundle) — نعيد حساب المجموع على الخادم من معرّفات
    // المحاضرات الفعلية، لا نثق بسعر العميل.
    if (id.startsWith('bundle:')) {
      const lectureIds = Array.isArray(it.bundleLectureIds) ? it.bundleLectureIds : [];
      if (lectureIds.length === 0 || lectureIds.length > 500) {
        throw new HttpsError('failed-precondition', 'محتوى المادة الكاملة غير صالح');
      }
      const lpDoc = await db.collection('settings').doc('pricing').get();
      const lp = lpDoc.exists ? lpDoc.data() : {};
      const pagePriceMap = { A4: lp.priceA4 || 100, A5: lp.priceA5 || 80, B5: lp.priceB5 || 90 };
      let bundlePrice = 0;
      for (const lecId of lectureIds) {
        const lecDoc = await db.collection('lectures').doc(String(lecId)).get();
        if (!lecDoc.exists) continue;
        const ld = lecDoc.data();
        const pageSize = ld.pageSize || 'A5';
        bundlePrice += ld.customPrice != null
          ? Number(ld.customPrice)
          : Number(ld.pages || 0) * (pagePriceMap[pageSize] || 80);
      }
      // رسوم التجليد (تسليك) من settings/pricing
      if (it.bindingType === 'تسليك') {
        const pricingDocForBinding = await db.collection('settings').doc('pricing').get();
        const bindingFee = pricingDocForBinding.exists
          ? Number(pricingDocForBinding.data().bindingPrice || 0)
          : 0;
        bundlePrice += bindingFee;
      }
      if (!Number.isFinite(bundlePrice) || bundlePrice <= 0) {
        throw new HttpsError('failed-precondition', 'سعر المادة الكاملة غير صالح');
      }
      const bundleItem = {
        title: String(it.title || id.replace('bundle:', '') + ' كامل'),
        price: bundlePrice,
        quantity: qty,
        isSupply: false,
        imageUrl: '',
      };
      if (it.bindingType) bundleItem.bindingType = String(it.bindingType);
      subtotal += bundlePrice * qty;
      verifiedItems.push(bundleItem);
      continue;
    }

    let ref;
    if (isSupply) {
      ref = db.collection('supply_products').doc(id);
    } else if (isLecture) {
      ref = db.collection('lectures').doc(id);
    } else {
      ref = db.collection('products').doc(id);
    }
    const doc = await ref.get();
    if (!doc.exists) {
      throw new HttpsError('failed-precondition', `المنتج ${id} غير موجود`);
    }
    const data = doc.data();
    if (data.available === false) {
      throw new HttpsError('failed-precondition', `المنتج "${data.title}" غير متوفر`);
    }
    let unitPrice;
    if (isSupply) {
      unitPrice = Number(data.price || 0);
    } else if (isLecture) {
      const lecturePricingDoc = await db.collection('settings').doc('page_pricing').get();
      const lp = lecturePricingDoc.exists ? lecturePricingDoc.data() : {};
      const pageSize = data.pageSize || 'A4';
      const pagePriceMap = { A4: lp.a4 || 10, A5: lp.a5 || 80, B5: lp.b5 || 90 };
      unitPrice = data.customPrice != null
        ? Number(data.customPrice)
        : Number(data.pages || 0) * (pagePriceMap[pageSize] || 10);
    } else {
      unitPrice = Number(data.pages || 0) * pricePerPage;
    }
    if (!Number.isFinite(unitPrice) || unitPrice < 0) {
      throw new HttpsError('failed-precondition', 'سعر غير صالح');
    }
    subtotal += unitPrice * qty;
    let displayTitle;
    if (isLecture) {
      const subject = data.subject || '';
      const lecNum = data.lectureNumber || '';
      const lecTitle = (data.title || '').trim();
      const defaultTitle = `محاضرة ${lecNum}`;
      const titleSuffix = lecTitle && lecTitle !== defaultTitle ? `: ${lecTitle}` : '';
      const firstLine = subject ? `${subject} — محاضرة ${lecNum}${titleSuffix}` : `${defaultTitle}${titleSuffix}`;
      const category = data.category || '';
      const year = data.year || '';
      const semester = data.semester || '';
      const archive = data.archiveSection || '';
      const ctx = [category, year, semester].filter(Boolean).join(' · ');
      const archiveLabel = archive && archive !== 'السنة الحالية' ? archive : '';
      displayTitle = ctx
        ? `${firstLine}\n${ctx}${archiveLabel ? ' · ' + archiveLabel : ''}`
        : firstLine;
    } else {
      displayTitle = data.title || '';
    }
    const verifiedItem = {
      title: displayTitle,
      price: unitPrice,
      quantity: qty,
      isSupply,
      imageUrl: data.imageUrl || '',
    };
    if (it.bindingType) verifiedItem.bindingType = String(it.bindingType);
    verifiedItems.push(verifiedItem);
  }

  // التحقق من كود الخصم وتطبيقه atomically
  let discount = 0;
  let appliedPromoId = null;
  if (promoCode && typeof promoCode === 'string') {
    const code = promoCode.toUpperCase();
    await db.runTransaction(async (tx) => {
      const snap = await db.collection('promo_codes')
        .where('code', '==', code)
        .where('active', '==', true)
        .limit(1)
        .get();
      if (snap.empty) {
        throw new HttpsError('failed-precondition', 'كود الخصم غير صالح');
      }
      const promoDoc = snap.docs[0];
      const promo = promoDoc.data();
      const now = Date.now();
      if (promo.expiresAt && promo.expiresAt.toMillis && promo.expiresAt.toMillis() < now) {
        throw new HttpsError('failed-precondition', 'كود الخصم منتهي');
      }
      const used = Number(promo.usedCount || 0);
      const limit = Number(promo.usageLimit || 0);
      if (limit > 0 && used >= limit) {
        throw new HttpsError('failed-precondition', 'كود الخصم استُنفد');
      }
      // احتساب الخصم
      const isPercent = promo.type === 'percent' || promo.isPercent === true;
      const value = Number(promo.discount || 0);
      discount = isPercent ? subtotal * value / 100 : value;
      if (discount > subtotal) discount = subtotal;
      appliedPromoId = promoDoc.id;
      tx.update(promoDoc.ref, { usedCount: FieldValue.increment(1) });
    });
  }

  // تقريب للأعلى لأقرب 100
  const rawTotal = Math.max(0, subtotal - discount);
  const total    = Math.ceil(rawTotal / 100) * 100;

  // رمز التسليم للاستلام الشخصي (4 أرقام)
  const pickupCode = isPickup
    ? String(Math.floor(1000 + Math.random() * 9000))
    : '';

  // إنشاء الطلب مع userId
  const orderRef = await db.collection('orders').add({
    userId: uid,
    userName: String(userName).trim(),
    phone: String(phone).trim(),
    address: typeof address === 'string' ? address.trim() : '',
    zone: typeof zone === 'string' ? zone.trim() : '',
    notes: typeof notes === 'string' ? notes.trim() : '',
    deliveryLat: isPickup ? 0 : (Number(deliveryLat) || 0),
    deliveryLng: isPickup ? 0 : (Number(deliveryLng) || 0),
    fcmToken: typeof fcmToken === 'string' ? fcmToken : '',
    items: verifiedItems,
    subtotal,
    discount,
    total,
    promoId: appliedPromoId,
    deliveryMethod: isPickup ? 'pickup' : 'delivery',
    paymentMethod: typeof paymentMethod === 'string' ? paymentMethod : 'cash',
    pickupCode,
    status: 'قيد المعالجة',
    createdAt: Timestamp.now(),
  });

  return { orderId: orderRef.id, total, discount, pickupCode };
});

// ════════════════════════════════════════════════════════════
//  تسجيل الدخول عبر تيليجرام (بديل الـ OTP عبر SMS)
//  التدفّق: التطبيق ينشئ جلسة → يفتح البوت → الطالب يضغط Start →
//  الـ webhook يوثّق الجلسة → التطبيق يطالب برمز مميّز (custom
//  token) ويسجّل الدخول بـ UID ثابت مربوط بحساب تيليجرام.
// ════════════════════════════════════════════════════════════

// مدة صلاحية الجلسة قبل انتهائها (بالدقائق)
const _TG_SESSION_TTL_MIN = 10;

// ── 1) بدء جلسة تسجيل دخول ─────────────────────────────────
// يستدعيه التطبيق (بمستخدم مجهول). يُنشئ وثيقة جلسة ويعيد
// معرّفها + اسم البوت لبناء رابط الفتح.
exports.startTelegramLogin = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
  }
  const d = request.data || {};
  const name = typeof d.name === 'string' ? d.name.trim().slice(0, 80) : '';
  const phone = typeof d.phone === 'string' ? d.phone.trim().slice(0, 40) : '';
  const specialty =
    typeof d.specialty === 'string' ? d.specialty.trim().slice(0, 80) : '';

  const botUsername = process.env.TELEGRAM_BOT_USERNAME || '';
  if (!botUsername) {
    throw new HttpsError('failed-precondition', 'البوت غير مُعدّ بعد');
  }

  // معرّف عشوائي بدون شرطات (يصلح كـ start param في تيليجرام)
  const sessionId = crypto.randomUUID().replace(/-/g, '');

  await db.collection('telegram_sessions').doc(sessionId).set({
    status: 'pending',
    requesterUid: uid,
    name,
    phone,
    specialty,
    createdAt: Timestamp.now(),
  });

  return { sessionId, botUsername };
});

// ── 2) Webhook يستقبل تحديثات البوت ────────────────────────
// يُضبط رابطه في تيليجرام عبر setWebhook مع secret_token.
exports.telegramWebhook = onRequest(
  { secrets: ['TELEGRAM_BOT_TOKEN', 'TELEGRAM_WEBHOOK_SECRET'] },
  async (req, res) => {
    // تحقّق أن الطلب فعلاً من تيليجرام
    const expectedSecret = process.env.TELEGRAM_WEBHOOK_SECRET || '';
    const gotSecret = req.get('X-Telegram-Bot-Api-Secret-Token') || '';
    if (!expectedSecret || gotSecret !== expectedSecret) {
      res.status(403).send('forbidden');
      return;
    }

    const token = process.env.TELEGRAM_BOT_TOKEN;
    const msg = req.body && req.body.message;
    const text = msg && typeof msg.text === 'string' ? msg.text : '';
    const chatId = msg && msg.chat && msg.chat.id;
    const from = msg && msg.from;
    const contact = msg && msg.contact;

    const send = async (body) => {
      try {
        await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ chat_id: chatId, ...body }),
        });
      } catch (_) {
        // تجاهل فشل الإرسال
      }
    };

    // ── مشاركة جهة الاتصال: توثيق الرقم الحقيقي ──
    if (contact && from && chatId) {
      // لازم يشارك رقمه هو، مش جهة اتصال من دفتره
      if (String(contact.user_id || '') !== String(from.id)) {
        await send({
          text: '❌ شارك رقمك أنت من الزر بالأسفل، وليس جهة اتصال أخرى.',
        });
        res.status(200).send('ok');
        return;
      }
      const q = await db
        .collection('telegram_sessions')
        .where('telegramUserId', '==', String(from.id))
        .where('status', '==', 'awaiting_phone')
        .limit(1)
        .get();
      if (q.empty) {
        await send({
          text: '❌ لا توجد جلسة بانتظار التحقق. أعد المحاولة من التطبيق.',
          reply_markup: { remove_keyboard: true },
        });
        res.status(200).send('ok');
        return;
      }
      let phone = String(contact.phone_number || '').replace(/[\s-]/g, '');
      if (phone && !phone.startsWith('+')) phone = `+${phone}`;
      await q.docs[0].ref.update({
        status: 'verified',
        phone,
        verifiedAt: Timestamp.now(),
      });
      await send({
        text: '✅ تم التحقق من رقمك بنجاح! عُد إلى التطبيق للمتابعة.',
        reply_markup: { remove_keyboard: true },
      });
      res.status(200).send('ok');
      return;
    }

    // ── أمر /start <sessionId>: اطلب مشاركة الرقم ──
    const match = /^\/start\s+([A-Za-z0-9_-]+)/.exec(text);
    if (!match || !from) {
      res.status(200).send('ok');
      return;
    }
    const sessionId = match[1];

    const ref = db.collection('telegram_sessions').doc(sessionId);
    const snap = await ref.get();

    if (!snap.exists) {
      if (chatId) {
        await send({
          text: '❌ انتهت صلاحية الجلسة أو أنها غير صحيحة. أعد المحاولة من التطبيق.',
        });
      }
      res.status(200).send('ok');
      return;
    }

    const s = snap.data();
    const ageMin = (Date.now() - s.createdAt.toDate().getTime()) / 60000;

    if (s.status === 'pending' && ageMin <= _TG_SESSION_TTL_MIN) {
      await ref.update({
        status: 'awaiting_phone',
        telegramUserId: String(from.id),
        telegramName:
          [from.first_name, from.last_name].filter(Boolean).join(' ') || '',
        telegramUsername: from.username || '',
        chatId: String(chatId || ''),
      });
      await send({
        text: 'أهلاً بك في مكتبة الكمال الطبية 📚\n\nلإكمال تسجيل الدخول، اضغط الزر بالأسفل لمشاركة رقم هاتفك المسجّل بتيليجرام.',
        reply_markup: {
          keyboard: [[{ text: '📱 مشاركة رقمي', request_contact: true }]],
          resize_keyboard: true,
          one_time_keyboard: true,
        },
      });
    } else if (s.status === 'awaiting_phone') {
      await send({
        text: 'بقي خطوة واحدة: اضغط زر «📱 مشاركة رقمي» بالأسفل.',
        reply_markup: {
          keyboard: [[{ text: '📱 مشاركة رقمي', request_contact: true }]],
          resize_keyboard: true,
          one_time_keyboard: true,
        },
      });
    } else if (s.status === 'verified' || s.status === 'claimed') {
      await send({ text: '✅ تم التحقق مسبقاً. عُد إلى التطبيق.' });
    } else {
      await send({
        text: '❌ انتهت صلاحية الجلسة. أعد المحاولة من التطبيق.',
      });
    }

    res.status(200).send('ok');
  },
);

// ── 3) المطالبة بالجلسة الموثّقة وإصدار رمز الدخول ─────────
// التطبيق يستدعيه بعد أن يرى الجلسة صارت verified. يتحقق أن
// المُطالِب هو نفسه من بدأ الجلسة، ثم يُصدر custom token بـ UID
// ثابت (tg_<telegramId>) ويمنع إعادة الاستخدام.
exports.claimTelegramSession = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
  }
  const sessionId = request.data && request.data.sessionId;
  if (typeof sessionId !== 'string' || !sessionId) {
    throw new HttpsError('invalid-argument', 'معرّف جلسة غير صحيح');
  }

  const ref = db.collection('telegram_sessions').doc(sessionId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'الجلسة غير موجودة');
  }
  const s = snap.data();
  if (s.requesterUid !== uid) {
    throw new HttpsError('permission-denied', 'هذه الجلسة لا تخصّك');
  }
  if (s.status !== 'verified') {
    throw new HttpsError('failed-precondition', 'لم يتم التحقق بعد');
  }

  const stableUid = `tg_${s.telegramUserId}`;

  // علّم الجلسة كمُستهلَكة قبل إصدار الرمز
  await ref.update({ status: 'claimed', claimedAt: Timestamp.now() });

  const customToken = await getAuth().createCustomToken(stableUid);
  return {
    token: customToken,
    name: s.name || '',
    phone: s.phone || '',
    specialty: s.specialty || '',
  };
});
