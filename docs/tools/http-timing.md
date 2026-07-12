# HTTP Timing · توقيت HTTP

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `http-timing`

---

## نظرة عامة · Overview
**بالعربي:** أداة توقيت HTTP تُنفّذ طلب HTTP/HTTPS واحدًا وتفكّكه إلى مراحل زمنية دقيقة (DNS، الاتصال، TLS، إرسال الطلب، الانتظار، التنزيل) لترسم شلالًا زمنيًا مصغّرًا يوضّح أين يُقضى الوقت. الأداة محلية بالكامل وتستخدم مكدّس الشبكة في النظام.
**English:** The HTTP Timing tool performs a single HTTP/HTTPS request and breaks it into precise phases (DNS, connect, TLS, request, wait, download) to draw a mini timing waterfall showing where time is spent. It runs entirely on-device using the system network stack.

## كيف تعمل · How it works
**بالعربي:** إذا لم يبدأ العنوان بـ `http` تضيف الأداة `https://` تلقائيًا. تُرسل الطلب عبر `URLSession` بإعداد `ephemeral` (بلا تخزين مؤقت) مع مهلة 20 ثانية، وتلتقط `URLSessionTaskMetrics` من مندوب الجلسة. من `transactionMetrics` تُحسب المراحل بالفروق الزمنية: **DNS** = `domainLookupStart→End`، **Connect** = `connectStart→End`، **TLS** = `secureConnectionStart→End`، **Request** = `requestStart→End`، **Wait (TTFB)** = `requestEnd→responseStart`، **Download** = `responseStart→responseEnd`. الإجمالي = `fetchStart→responseEnd`. القيم بالمللي ثانية والمراحل غير المتاحة تُحذف.
**English:** If the URL does not start with `http`, the tool prepends `https://`. It issues the request through an `ephemeral` `URLSession` (no caching) with a 20-second timeout and captures `URLSessionTaskMetrics` via the session delegate. From `transactionMetrics` it computes each phase as a time delta: **DNS** = `domainLookupStart→End`, **Connect** = `connectStart→End`, **TLS** = `secureConnectionStart→End`, **Request** = `requestStart→End`, **Wait (TTFB)** = `requestEnd→responseStart`, **Download** = `responseStart→responseEnd`. Total = `fetchStart→responseEnd`. Values are in milliseconds; unavailable phases are omitted.

## المدخلات · Inputs
- **URL / العنوان:** عنوان الصفحة أو نقطة النهاية (مثل `https://apple.com`). إن غاب البروتوكول يُفترض `https`. / Page or endpoint URL; `https` is assumed if the scheme is missing.

## المخرجات · Outputs
**بالعربي:** رمز حالة HTTP (بشارة خضراء للنطاق 200–399)، والإجمالي بالمللي ثانية، وقائمة المراحل يقابل كل منها شريط أفقي يتناسب طوله مع زمنها لمقارنة بصرية سريعة.
**English:** The HTTP status code (green badge for 200–399), the total in milliseconds, and a list of phases each with a horizontal bar whose length is proportional to its duration for quick visual comparison.

## مثال تشغيل · Worked example
**بالعربي:** المدخل `https://apple.com`. النتيجة: الحالة `200`، الإجمالي `312 ms`، والمراحل مثل `DNS 18 ms`، `Connect 40 ms`، `TLS 65 ms`، `Request 1 ms`، `Wait (TTFB) 150 ms`، `Download 38 ms`.
**English:** Input `https://apple.com`. Result: status `200`, total `312 ms`, with phases such as `DNS 18 ms`, `Connect 40 ms`, `TLS 65 ms`, `Request 1 ms`, `Wait (TTFB) 150 ms`, `Download 38 ms`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** يقيس طلبًا واحدًا فقط، فقد تتفاوت الأرقام بين المحاولات بحسب الشبكة و التخزين المؤقت لدى الخادم. مرحلة TLS تظهر للاتصالات المؤمّنة فقط، وقد تختفي مراحل (مثل DNS أو Connect) عند إعادة استخدام اتصال قائم. لا يتطلب أذونات خاصة على iOS.
**English:** It measures a single request, so numbers vary between runs depending on the network and server-side caching. The TLS phase appears only for secure connections, and phases such as DNS or Connect may be absent when an existing connection is reused. No special iOS permissions are required.
