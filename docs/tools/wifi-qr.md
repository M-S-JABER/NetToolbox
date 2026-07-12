# Wi‑Fi QR Generator · مولّد رمز QR للواي‑فاي

> **Category / التصنيف:** Local Network / الشبكة المحلية  
> **Tool ID:** `wifi-qr`

---

## نظرة عامة · Overview
**بالعربي:** يولّد هذا الأداة رمز QR لشبكة Wi‑Fi، بحيث يستطيع أي هاتف مسحه بالكاميرا للاتصال بالشبكة تلقائيًّا دون كتابة كلمة المرور. المولّد يعمل بالكامل محليًّا على الجهاز — لا يُرسل أي بيانات إلى أي خادم.
**English:** This tool generates a Wi‑Fi QR code so any phone can scan it with the camera and join the network automatically without typing the password. The generator runs entirely on‑device — no data is sent to any server.

## كيف تعمل · How it works
**بالعربي:** هذا مولّد محلي بحت، ولا يُجري أي اتصال شبكي إطلاقًا. يبني نصًّا وفق مخطط `WIFI:` القياسي الذي تفهمه كاميرات iOS وAndroid: `WIFI:T:<الأمان>;S:<اسم الشبكة>;P:<كلمة المرور>;H:<مخفية>;;`. يُهرِّب الرموز الخاصة (`\ ; , : "`) في اسم الشبكة وكلمة المرور بإضافة `\` قبلها. عند اختيار «بدون كلمة مرور» يُحذف حقل `P`. ثم يُرمَّز النص إلى صورة QR عبر `CoreImage` (مرشّح `CIQRCodeGenerator`) وتُعرض كصورة عالية الحدّة. دالة بناء النص نقيّة ومغطّاة باختبارات وحدة.
**English:** This is a purely local generator and performs no networking whatsoever. It builds a string following the standard `WIFI:` scheme that iOS and Android cameras understand: `WIFI:T:<security>;S:<ssid>;P:<password>;H:<hidden>;;`. Special characters (`\ ; , : "`) in the SSID and password are escaped by prefixing a `\`. When "no password" is selected the `P` field is omitted. The string is then encoded to a QR image via `CoreImage` (the `CIQRCodeGenerator` filter) and shown as a crisp image. The payload builder is pure and unit‑tested.

## المدخلات · Inputs
**بالعربي:**
- **اسم الشبكة (SSID):** إلزامي — لا يظهر الرمز حتى يُملأ.
- **نوع الأمان (Security):** اختيار مقسّم بين `WPA` (يشمل WPA2/WPA3)، و`WEP`، و`nopass` (بدون كلمة مرور).
- **كلمة المرور (Password):** حقل آمن يظهر فقط عندما لا يكون الأمان `nopass`.
- **شبكة مخفية (Hidden):** مفتاح تبديل يضبط الحقل `H` على `true`/`false` (للشبكات التي لا تبثّ اسمها).
**English:**
- **SSID:** required — the code does not appear until it is filled.
- **Security:** a segmented choice between `WPA` (covers WPA2/WPA3), `WEP`, and `nopass` (open network).
- **Password:** a secure field shown only when security is not `nopass`.
- **Hidden:** a toggle that sets the `H` field to `true`/`false` (for networks that do not broadcast their name).

## المخرجات · Outputs
**بالعربي:** صورة رمز QR على خلفية بيضاء بمجرد إدخال اسم الشبكة، تُحدَّث فورًا مع كل تغيير في الحقول. يمكن مسحها مباشرةً بكاميرا أي هاتف للاتصال بالشبكة.
**English:** A QR code image on a white background as soon as the SSID is entered, updated live with every field change. It can be scanned directly by any phone's camera to join the network.

## مثال تشغيل · Worked example
**بالعربي:** تُدخل SSID `MyHomeWiFi`، وتختار الأمان `WPA`، وتكتب كلمة المرور `p@ss;word`، وتترك «مخفية» معطّلة. يبني المولّد النص `WIFI:T:WPA;S:MyHomeWiFi;P:p@ss\;word;H:false;;` (لاحظ تهريب الفاصلة المنقوطة) ويعرض رمز QR. يمسحه ضيفك بكاميرا هاتفه فيتصل بالشبكة فورًا.
**English:** You enter SSID `MyHomeWiFi`, pick `WPA` security, type password `p@ss;word`, and leave "hidden" off. The generator builds the string `WIFI:T:WPA;S:MyHomeWiFi;P:p@ss\;word;H:false;;` (note the escaped semicolon) and shows the QR code. Your guest scans it with their phone camera and connects instantly.

## ملاحظات وقيود · Notes & limitations
**بالعربي:**
- هذه الأداة مولّد محلي بالكامل ولا تتصل بالشبكة إطلاقًا، لذا **لا تتطلب صلاحية «الشبكة المحلية»** ولا أي أذونات شبكية. (بقيّة أدوات التطبيق التي تخاطب الشبكة تتطلبها؛ لتفعيلها: **الإعدادات ← NetToolbox ← الشبكة المحلية**.)
- الأداة لا تقرأ شبكتك الحالية ولا كلمة مرورها؛ يجب إدخال البيانات يدويًّا لأن iOS لا يتيح للتطبيقات قراءة كلمة مرور Wi‑Fi.
- توافق مسح رمز QR للاتصال متوفّر في كاميرا iOS 11+ وأغلب هواتف Android الحديثة؛ الأجهزة الأقدم قد لا تدعمه.
**English:**
- This tool is a fully local generator and does no networking at all, so it **does not require the Local Network permission** or any network access. (The app's other tools that touch the network do; enable it via **Settings ← NetToolbox ← Local Network**.)
- The tool cannot read your current network or its password; you must enter the details manually because iOS does not let apps read the Wi‑Fi password.
- QR‑to‑connect scanning is supported by the iOS 11+ camera and most modern Android phones; older devices may not support it.
