# NSLookup · استعلام DNS

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `nslookup`

---

## نظرة عامة · Overview
**بالعربي:** أداة NSLookup تحوّل اسم النطاق إلى عناوين IP (بحث أمامي)، أو تحوّل عنوان IPv4 إلى اسم المضيف (بحث عكسي / PTR). تكتشف تلقائيًا نوع المدخل وتختار الوضع المناسب، معتمدةً على مُحلِّل النظام دون خادم DNS مخصّص.
**English:** The NSLookup tool resolves a domain name to IP addresses (forward lookup) or resolves an IPv4 address to its hostname (reverse / PTR lookup). It auto-detects the input type and picks the right mode, using the system resolver rather than a custom DNS server.

## كيف تعمل · How it works
**بالعربي:** إذا صنّف `InputClassifier.isIPv4` المدخل كعنوان IPv4، تعمل الأداة في **الوضع العكسي**: تبني بنية `sockaddr_in` وتستدعي `getnameinfo` مع راية `NI_NAMEREQD` للحصول على سجل PTR (اسم المضيف). خلاف ذلك تعمل في **الوضع الأمامي**: يستدعي `SystemHostResolver` الدالة `getaddrinfo` (بعائلة `AF_UNSPEC`) لجمع كل عناوين IPv4 وIPv6، ثم `getnameinfo` مع `NI_NUMERICHOST` لتنسيقها نصيًا. كلا المسارين يستخدم مُحلِّل DNS المُهيّأ في نظام التشغيل عبر واجهات POSIX، ويعملان على خيط خلفي حتى لا يُجمَّد الواجهة.
**English:** If `InputClassifier.isIPv4` classifies the input as an IPv4 address, the tool runs in **reverse mode**: it builds a `sockaddr_in` and calls `getnameinfo` with the `NI_NAMEREQD` flag to obtain the PTR record (hostname). Otherwise it runs in **forward mode**: `SystemHostResolver` calls `getaddrinfo` (family `AF_UNSPEC`) to gather all IPv4 and IPv6 addresses, then `getnameinfo` with `NI_NUMERICHOST` to format them as text. Both paths use the OS-configured DNS resolver through POSIX APIs and run on a background thread so the UI is not blocked.

## المدخلات · Inputs
- **Query / الاستعلام:** اسم نطاق (مثل `apple.com`) للبحث الأمامي، أو عنوان IPv4 (مثل `8.8.8.8`) للبحث العكسي. يعرض الوضع الحالي (Forward/Reverse) تلقائيًا. / A domain name for forward lookup or an IPv4 address for reverse lookup; the current mode is shown automatically.

## المخرجات · Outputs
**بالعربي:** في الوضع الأمامي: قائمة عناوين مع بشارة `IPv4` أو `IPv6` لكل عنوان، وكل قيمة قابلة للنسخ. في الوضع العكسي: اسم المضيف الناتج. إن لم يُعثر على نتيجة يظهر `Not found`.
**English:** In forward mode: a list of addresses each tagged `IPv4` or `IPv6`, each copyable. In reverse mode: the resulting hostname. If nothing resolves, `Not found` is shown.

## مثال تشغيل · Worked example
**بالعربي:** المدخل `dns.google` (أمامي) يعيد `8.8.8.8` و`8.8.4.4` وعناوين IPv6. المدخل `8.8.8.8` (عكسي) يعيد اسم المضيف `dns.google`.
**English:** Input `dns.google` (forward) returns `8.8.8.8`, `8.8.4.4`, and IPv6 addresses. Input `8.8.8.8` (reverse) returns the hostname `dns.google`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** البحث العكسي يدعم IPv4 فقط ويتطلب وجود سجل PTR للمضيف. النتائج تخضع للتخزين المؤقت لدى مُحلِّل النظام. لا يتطلب أذونات خاصة على iOS (تحليل DNS عام).
**English:** Reverse lookup supports IPv4 only and requires the host to have a PTR record. Results are subject to the system resolver's cache. No special iOS permissions are required (public DNS resolution).
