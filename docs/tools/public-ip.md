# Public IP & ISP · العنوان العام ومزوّد الخدمة

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `public-ip`

---

## نظرة عامة · Overview
**بالعربي:** تعرض هذه الأداة عنوان IP العام لجهازك مع تفاصيل الموقع الجغرافي ومزوّد الخدمة (ISP)، إضافة إلى عناوين الواجهات المحلية على الجهاز. يتم تحديث المعلومات تلقائيًا عند فتح الشاشة، ويمكن السحب للأسفل لإعادة التحديث.
**English:** This tool shows your device's public IP with geo/ISP details, plus the device's local interface addresses. Data loads automatically when the screen opens, and you can pull to refresh.

## كيف تعمل · How it works
**بالعربي:** يرسل التطبيق طلب HTTPS إلى `https://ipwho.is/` (خدمة ipwho.is المجانية) دون تمرير أي عنوان، فيعيد الخادم عنوانك العام كما يراه مع بيانات الدولة والمدينة وخط الطول والعرض ومزوّد الخدمة ورقم النظام المستقل (ASN) والمنطقة الزمنية. أما العناوين المحلية فتُقرأ مباشرة من واجهات الجهاز عبر `SystemLocalIPProvider` محليًا دون أي اتصال. البروتوكول: HTTPS على المنفذ `443`؛ لا يُستخدم ICMP هنا.
**English:** The app sends an HTTPS request to `https://ipwho.is/` (the free ipwho.is service) with no address in the path, so the server returns your public IP as it sees it, along with country, city, latitude/longitude, ISP, ASN, and timezone. The local addresses are read directly from the device's interfaces via `SystemLocalIPProvider`, entirely on-device with no network call. Protocol: HTTPS on port `443`; no ICMP is used here.

## المدخلات · Inputs
**بالعربي:** لا توجد حقول إدخال — تعمل الأداة على جهازك أنت. زر التحديث (`arrow.clockwise`) يعيد الاستعلام فقط.
**English:** No input fields — the tool operates on your own device. The refresh button (`arrow.clockwise`) just re-runs the query.

## المخرجات · Outputs
**بالعربي:** قسم "العام": عنوان IP قابل للنسخ، شارة "متصل"، الدولة (مع رمزها)، المدينة، مزوّد الخدمة، المؤسسة، `ASNxxxxx`، المنطقة الزمنية. قسم "المحلي": قائمة بعناوين واجهات الجهاز مع شارة IPv4/IPv6 واسم الواجهة.
**English:** "Public" section: a copyable IP, an "online" badge, country (with code), city, ISP, organization, `ASNxxxxx`, and timezone. "Local" section: a list of the device's interface addresses, each tagged IPv4/IPv6 with its interface name.

## مثال تشغيل · Worked example
**بالعربي:** فتح الأداة ← العام: `203.0.113.5`، الدولة "Saudi Arabia (SA)"، المدينة "Riyadh"، ISP "Saudi Telecom Company"، `AS39386`، المنطقة `Asia/Riyadh`. المحلي: `en0` → `192.168.1.20` (IPv4) و`fe80::1c2d:...` (IPv6).
**English:** Open the tool → Public: `203.0.113.5`, country "Saudi Arabia (SA)", city "Riyadh", ISP "Saudi Telecom Company", `AS39386`, zone `Asia/Riyadh`. Local: `en0` → `192.168.1.20` (IPv4) and `fe80::1c2d:...` (IPv6).

## ملاحظات وقيود · Notes & limitations
**بالعربي:** البيانات الجغرافية تقريبية وتعتمد على قاعدة بيانات ipwho.is وقد لا تعكس موقعك الحقيقي بدقة. الاستعلام يُرسِل طلبًا واحدًا إلى ipwho.is فقط؛ لا تُرسَل العناوين المحلية إلى أي جهة. يتطلب اتصال إنترنت للقسم العام؛ القسم المحلي يعمل دون إنترنت.
**English:** Geo data is approximate, based on the ipwho.is database, and may not reflect your true location precisely. The query sends a single request to ipwho.is only; local addresses are never transmitted. Internet is required for the public section; the local section works offline.
