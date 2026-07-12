# Network Overview · نظرة عامة على الشبكة

> **Category / التصنيف:** Local Network / الشبكة المحلية  
> **Tool ID:** `network-overview`

---

## نظرة عامة · Overview
**بالعربي:** تعرض هذه الأداة لوحة موجزة عن حالة اتصال جهازك بالشبكة: نوع الاتصال الحالي (Wi‑Fi / خلوي / غير متصل)، وعنوان الـ IP العام مع بيانات مزوّد الخدمة والدولة، وقائمة بعناوين IP المحلية لكل واجهة شبكة على الجهاز. إنها نقطة البداية لفهم موقعك في الشبكة قبل استخدام أدوات الفحص الأخرى.
**English:** This tool shows a compact dashboard of your device's connectivity: the current connection type (Wi‑Fi / cellular / offline), your public IP with ISP and country details, and the list of local IP addresses for every active network interface on the device. It is the natural starting point for understanding where you sit on the network before using the other scanning tools.

## كيف تعمل · How it works
**بالعربي:** تجمع الأداة معلوماتها من ثلاثة مصادر: (1) حالة الاتصال تأتي من `NetworkStatusMonitor` المبني على `NWPathMonitor` من إطار Network، ويكشف أيضًا ما إذا كان الاتصال «محدود التكلفة/metered». (2) العناوين المحلية تُقرأ محليًا عبر `getifaddrs()` (النظام `SystemLocalIPProvider`) لكل واجهة نشطة غير loopback، مع تصنيف كل عنوان `IPv4` أو `IPv6` — لا تتطلب هذه القراءة أي صلاحية خاصة. (3) الـ IP العام يُجلب عبر طلب HTTPS إلى الخدمة المجانية `https://ipwho.is/`، التي تعيد الـ IP الظاهر للإنترنت مع الدولة ورمزها ومزوّد الخدمة (ISP). يحدث التحديث تلقائيًا عند فتح الشاشة، ويمكن إعادته بالسحب للأسفل (pull‑to‑refresh).
**English:** The tool draws on three sources: (1) connection status comes from `NetworkStatusMonitor`, built on Network framework's `NWPathMonitor`, which also flags whether the link is "metered"/expensive. (2) Local addresses are read on‑device via `getifaddrs()` (`SystemLocalIPProvider`) for every active non‑loopback interface, each tagged `IPv4` or `IPv6` — this read needs no special permission. (3) The public IP is fetched with an HTTPS request to the free `https://ipwho.is/` endpoint, which returns your internet‑facing IP along with country, country code, and ISP. It refreshes automatically when the screen opens and can be re‑run with pull‑to‑refresh.

## المدخلات · Inputs
**بالعربي:** لا توجد حقول إدخال. الأداة تعمل تلقائيًا؛ الإجراء الوحيد المتاح هو السحب للأسفل لإعادة التحديث.
**English:** No input fields. The tool runs automatically; the only action available is pull‑to‑refresh to reload.

## المخرجات · Outputs
**بالعربي:**
- **بطاقة الاتصال:** أيقونة ونص يوضحان نوع الاتصال (Wi‑Fi / خلوي / غير متصل)، مع شارة «محدود التكلفة» إن كان الاتصال metered.
- **بطاقة الـ IP العام:** العنوان العام مثل `176.44.x.x` (قابل للنسخ)، ومزوّد الخدمة (ISP)، والدولة مع رمزها مثل `Saudi Arabia (SA)`.
- **بطاقة العناوين المحلية:** صف لكل واجهة يعرض اسم الواجهة مثل `en0`، وشارة `IPv4`/`IPv6`، والعنوان مثل `192.168.1.20` (قابل للنسخ).
**English:**
- **Connection card:** icon and label for the connection type (Wi‑Fi / cellular / offline), plus a "metered" badge when the link is expensive.
- **Public IP card:** the public address such as `176.44.x.x` (copyable), the ISP, and the country with its code such as `Saudi Arabia (SA)`.
- **Local addresses card:** one row per interface showing the interface name such as `en0`, an `IPv4`/`IPv6` badge, and the address such as `192.168.1.20` (copyable).

## مثال تشغيل · Worked example
**بالعربي:** تفتح الأداة على شبكة منزلية عبر Wi‑Fi. تعرض بطاقة الاتصال «Wi‑Fi». بعد لحظة تظهر بطاقة الـ IP العام: العنوان `188.53.120.44`، ISP: `Saudi Telecom Company`، الدولة: `Saudi Arabia (SA)`. وتُظهر بطاقة العناوين المحلية صفَّين: `en0 · IPv4 · 192.168.8.101` و`en0 · IPv6 · fe80::14c3:...`.
**English:** You open the tool on a home Wi‑Fi network. The connection card reads "Wi‑Fi." A moment later the public IP card shows: address `188.53.120.44`, ISP `Saudi Telecom Company`, country `Saudi Arabia (SA)`. The local addresses card lists two rows: `en0 · IPv4 · 192.168.8.101` and `en0 · IPv6 · fe80::14c3:...`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:**
- قراءة عناوين جهازك المحلية عبر `getifaddrs()` لا تتطلب صلاحية «الشبكة المحلية»، لكن العديد من الأدوات الأخرى في التطبيق (فحص الشبكة، الكاميرات، إلخ) تتطلبها. لتفعيلها: **الإعدادات ← NetToolbox ← الشبكة المحلية**. بدون هذه الصلاحية تُرجع أدوات الاكتشاف نتائج فارغة.
- جلب الـ IP العام يحتاج اتصالًا فعّالًا بالإنترنت؛ إن فشل الطلب تُعرض رسالة خطأ بدل البيانات.
- العنوان `fe80::` هو عنوان IPv6 محلي للرابط (link‑local) وهو طبيعي.
**English:**
- Reading your own local addresses via `getifaddrs()` does not require the Local Network permission, but many other tools in the app (network scanning, cameras, etc.) do. To enable it: **Settings ← NetToolbox ← Local Network**. Without this permission the discovery tools return empty results.
- Fetching the public IP needs a working internet connection; if the request fails an error message is shown instead of the data.
- An `fe80::` address is an IPv6 link‑local address and is normal.
