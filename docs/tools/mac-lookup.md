# MAC / OUI Lookup · بحث عنوان MAC والشركة المصنّعة

> **Category / التصنيف:** Calculators / الحاسبات  
> **Tool ID:** `mac-lookup`

---

## نظرة عامة · Overview
**بالعربي:** أداة تحلّل عنوان `MAC` (48-بت) بأي صيغة إدخال شائعة، تُطبّعه، وتحدّد الشركة المصنّعة من أول ثلاث بايتات (OUI) عبر قاعدة بيانات مدمجة داخل التطبيق. كما تكشف خصائص العنوان: هل هو multicast (بت I/G) وهل هو مُدار محلياً (بت U/L) وهو ما يميّز عناوين MAC العشوائية/الخاصة في iOS وAndroid.
**English:** A tool that parses a 48-bit `MAC` address in any common input format, normalizes it, and identifies the manufacturer from the first three bytes (the OUI) using a database bundled inside the app. It also reveals address traits: whether it is multicast (the I/G bit) and whether it is locally administered (the U/L bit), which marks the randomized/private MACs used by iOS and Android.

## كيف تعمل · How it works
**بالعربي:** التحليل في بنية `MACAddress` والبحث عن الشركة عبر `BundledOUIDatabase` — **يعمل محلياً بالكامل بدون اتصال بالإنترنت**. يقبل الإدخال بأي فواصل (`:` أو `-` أو `.` أو مسافات) أو بدونها، يزيل الفواصل، ويتحقق أن الناتج 12 خانة hex. يستخرج مفتاح OUI (أول 3 بايت) ويبحث عنه في ملف `oui.json` المدمج (سجل مختصر للشركات المعروفة) بحثاً O(1). بتّا multicast وlocally-administered يُقرآن مباشرة من أول بايت (`octet & 0b1` و`octet & 0b10`). لا استعلام IEEE عن بُعد ولا أي شبكة.
**English:** Parsing lives in the `MACAddress` struct and vendor lookup in `BundledOUIDatabase` — **runs 100% on-device, no network**. It accepts input with any separators (`:`, `-`, `.`, spaces) or none, strips them, and verifies the result is 12 hex digits. It extracts the OUI key (first 3 bytes) and looks it up in the bundled `oui.json` (an abridged registry of well-known vendors) in O(1). The multicast and locally-administered bits are read directly from the first byte (`octet & 0b1` and `octet & 0b10`). No remote IEEE query, no network at all.

## المدخلات · Inputs
| Field · الحقل | الوصف · Description |
|---|---|
| `input` | عنوان MAC بأي صيغة: `AA:BB:CC:DD:EE:FF` أو `aa-bb-cc-dd-ee-ff` أو `aabb.ccdd.eeff` (Cisco) أو `aabbccddeeff`. A MAC address in any common format. |

## المخرجات · Outputs
**بالعربي:** الصيغة المُطبّعة `AA:BB:CC:DD:EE:FF`، الصيغة النقطية بأسلوب Cisco `aabb.ccdd.eeff`، مفتاح OUI (أول 3 بايت)، اسم الشركة المصنّعة إن وُجد في القاعدة، ومؤشرا Multicast وLocally-administered. الإدخال غير الصالح يُظهر رسالة خطأ.
**English:** The normalized form `AA:BB:CC:DD:EE:FF`, the Cisco dotted form `aabb.ccdd.eeff`, the OUI key (first 3 bytes), the vendor name if present in the database, and the Multicast and Locally-administered flags. Invalid input shows an error message.

## مثال تشغيل · Worked example
**بالعربي:** إدخال `f0:18:98:12:34:56` →
- مُطبّع: `F0:18:98:12:34:56` · Cisco: `f018.9812.3456`
- OUI: `F01898` · الشركة: Apple, Inc. (إن كانت في القاعدة المدمجة)
- Multicast: لا (البايت الأول `F0` زوجي في البت الأدنى) · Locally administered: لا

**English:** Input `f0:18:98:12:34:56` →
- Normalized: `F0:18:98:12:34:56` · Cisco: `f018.9812.3456`
- OUI: `F01898` · Vendor: Apple, Inc. (if present in the bundled DB)
- Multicast: No · Locally administered: No

## ملاحظات وقيود · Notes & limitations
**بالعربي:** قاعدة الشركات مختصرة (تحتوي على الشركات المعروفة فقط)، لذا قد تُطبَّع بعض العناوين بنجاح دون إظهار اسم الشركة. العناوين العشوائية في الهواتف الحديثة تظهر عادةً بعلامة Locally-administered ولا يوجد لها مُصنّع. لا يُرسل العنوان لأي خادم — الخصوصية كاملة.
**English:** The vendor database is abridged (well-known vendors only), so some addresses normalize successfully without a vendor name. Randomized MACs on modern phones typically show the Locally-administered flag and have no manufacturer. The address is never sent to any server — fully private.
