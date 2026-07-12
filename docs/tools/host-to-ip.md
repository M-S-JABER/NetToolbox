# Host → IP · تحويل المضيف إلى عنوان

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `host-to-ip`

---

## نظرة عامة · Overview
**بالعربي:** أداة بسيطة تُحوّل اسم المضيف (domain) إلى عناوين IPv4 وIPv6 الخاصة به باستخدام مُحلِّل النظام في iOS. تعمل محليًا عبر نفس المسار الذي تستخدمه التطبيقات العادية، ولا تتطلب أي إذن خاص.
**English:** A simple tool that resolves a hostname to its IPv4 and IPv6 addresses using the iOS system resolver. It works through the same path normal apps use and requires no special permission.

## كيف تعمل · How it works
**بالعربي:** تستدعي الأداة دالة `getaddrinfo` من نظام التشغيل مع `AF_UNSPEC` (أي العائلتين IPv4 وIPv6) و`SOCK_STREAM`. تُنفَّذ العملية على خيط خلفي، ثم تُحوَّل كل نتيجة إلى نص رقمي عبر `getnameinfo` مع الراية `NI_NUMERICHOST`، وتُزال التكرارات. لا يوجد بروتوكول DNS خام أو منفذ محدد — يتولّى النظام اختيار خوادم DNS المضبوطة على الجهاز. لا اتصال ICMP.
**English:** The tool calls the OS `getaddrinfo` with `AF_UNSPEC` (both IPv4 and IPv6) and `SOCK_STREAM`. It runs on a background queue, then converts each result to a numeric string via `getnameinfo` with the `NI_NUMERICHOST` flag, de-duplicating entries. There is no raw DNS protocol or fixed port — the OS uses whatever DNS servers the device is configured with. No ICMP involved.

## المدخلات · Inputs
**بالعربي:** حقل نصي واحد لاسم المضيف (مثل `apple.com`). يدعم اختيار مضيف محفوظ من قائمة "المضيفين المحفوظين". الضغط على "تحليل" أو Enter يبدأ العملية.
**English:** A single text field for the hostname (e.g. `apple.com`). Supports picking a saved host from the Saved Hosts menu. Tapping "Resolve" or pressing Enter starts it.

## المخرجات · Outputs
**بالعربي:** قائمة بالعناوين، كل عنوان مع شارة نوعه: IPv4 (شارة info) أو IPv6 (شارة محايدة)، وقيمة قابلة للنسخ. إذا لم يُعثَر على أي عنوان تظهر رسالة "غير موجود".
**English:** A list of addresses, each with a type badge — IPv4 (info badge) or IPv6 (neutral badge) — and a copyable value. If no address is found, a "not found" message appears.

## مثال تشغيل · Worked example
**بالعربي:** إدخال `apple.com` ← يعرض عنوان IPv4 مثل `17.253.144.10` وعناوين IPv6 إن توفّرت. إدخال اسم غير موجود ← "غير موجود".
**English:** Enter `apple.com` → shows an IPv4 like `17.253.144.10` plus IPv6 addresses if available. Enter a nonexistent name → "not found".

## ملاحظات وقيود · Notes & limitations
**بالعربي:** يعتمد على إعدادات DNS للجهاز، فقد تختلف النتائج حسب الشبكة أو مزوّد الخدمة. لا يتطلب إذن الشبكة المحلية لأنه حلّ DNS عام. النتائج تعكس أول مجموعة يعيدها النظام وقد لا تشمل كل عناوين النطاق. يعمل بلا حاجة إلى إذونات خاصة، لكنه يتطلب اتصالًا يصل إلى مُحلِّل DNS.
**English:** It relies on the device's DNS configuration, so results can vary by network or ISP. No Local Network permission is needed since this is public DNS resolution. Results reflect the first set the system returns and may not include every address of the domain. It needs no special permission but does need connectivity to reach a DNS resolver.
