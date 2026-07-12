# Speed Test · اختبار السرعة

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `speed-test`

---

## نظرة عامة · Overview
**بالعربي:** يقيس اختبار السرعة زمن الاستجابة (latency) والاهتزاز (jitter) وسرعة التنزيل والرفع، إضافةً إلى قياس "bufferbloat" (زيادة زمن الاستجابة تحت الحِمل) ونسبة فقد الحزم. يعمل على بنية Cloudflare المفتوحة نفسها التي يقوم عليها موقع speed.cloudflare.com.
**English:** The Speed Test measures latency, jitter, download and upload throughput, plus bufferbloat (latency growth under load) and probe loss. It runs against the same open Cloudflare infrastructure that backs speed.cloudflare.com.

## كيف تعمل · How it works
**بالعربي:** المحرّك `CloudflareSpeedEngine` يبثّ نتائج تدريجية عبر عدة مراحل باستخدام `URLSession` (جلسة مؤقتة بلا تخزين) على HTTPS منفذ `443`:
- **البيانات الوصفية:** طلب `https://speed.cloudflare.com/meta` لمعرفة عنوان العميل ومزوّده وعقدة Cloudflare (colo) والموقع.
- **زمن الاستجابة:** 12 طلبًا إلى `https://speed.cloudflare.com/__down?bytes=0`؛ تُهمَل العيّنة الأولى (تكلفة TLS)، ثم يُؤخذ الأدنى كـ ping ومتوسط الفروق كـ jitter.
- **التنزيل:** سحب متتالٍ لقطع 20 مليون بايت من `__down?bytes=20000000` لمدة 8 ثوانٍ مع فترة إحماء ثانية واحدة، والحساب بالميغابت/ث.
- **الرفع:** إرسال POST لحمولة 4 ميغابايت إلى `https://speed.cloudflare.com/__up` بشكل متكرر لمدة 6 ثوانٍ.
- **bufferbloat والفقد:** أثناء الحِمل تُقاس عيّنات زمن الاستجابة كل 250 مللي؛ يُحسَب مقدار الزيادة عن الحالة الخاملة ويُمنَح تقدير (A+ حتى F)، ونسبة الطلبات الفاشلة كنسبة فقد.

لا يوجد ICMP هنا؛ كل القياسات عبر HTTPS.
**English:** The `CloudflareSpeedEngine` streams incremental results across several phases using `URLSession` (an ephemeral, cacheless session) over HTTPS on port `443`:
- **Metadata:** requests `https://speed.cloudflare.com/meta` for the client IP, ISP, Cloudflare node (colo), and location.
- **Latency:** 12 requests to `https://speed.cloudflare.com/__down?bytes=0`; the first sample is dropped (TLS setup), then the minimum is the ping and the mean of consecutive deltas is the jitter.
- **Download:** back-to-back 20 MB chunks from `__down?bytes=20000000` for 8 seconds with a 1-second warmup, computed in Mbps.
- **Upload:** repeated POST of a 4 MB payload to `https://speed.cloudflare.com/__up` for 6 seconds.
- **Bufferbloat & loss:** during load, latency samples are taken every 250 ms; the increase over idle is graded (A+ down to F), and the fraction of failed probes is the loss percentage.

There is no ICMP here; every measurement is over HTTPS.

## المدخلات · Inputs
**بالعربي:** لا حقول إدخال — زر "بدء / إعادة" فقط. المدد والأحجام ثابتة داخل المحرّك (تنزيل 8ث، رفع 6ث، إحماء 1ث).
**English:** No input fields — just a Start/Restart button. Durations and sizes are fixed in the engine (8s download, 6s upload, 1s warmup).

## المخرجات · Outputs
**بالعربي:** عدّاد حي بالميغابت/ث أثناء التشغيل، ثم بطاقة نتائج: تنزيل، رفع، ping، jitter، وإن توفّر: تقدير bufferbloat مع مقدار الزيادة (+ms) ونسبة الفقد. بطاقة الخادم تُظهر ISP والموقع وعقدة colo وعنوان العميل. تُحفَظ كل نتيجة في سجل السرعة (مع رسم Sparkline لآخر النتائج).
**English:** A live Mbps gauge while running, then a results card: download, upload, ping, jitter, and when available a bufferbloat grade with its increase (+ms) and loss percentage. A server card shows ISP, location, colo node, and client IP. Each run is saved to the speed history (with a Sparkline of recent runs).

## مثال تشغيل · Worked example
**بالعربي:** الضغط على "بدء" ← الخادم: STC Riyadh عبر عقدة `JED`؛ النتائج: تنزيل `248.6 Mbps`، رفع `41.3 Mbps`، ping `12 ms`، jitter `3 ms`، bufferbloat `A` بزيادة `+18 ms`، فقد `0%`.
**English:** Tap Start → Server: STC Riyadh via colo `JED`; results: download `248.6 Mbps`, upload `41.3 Mbps`, ping `12 ms`, jitter `3 ms`, bufferbloat `A` at `+18 ms`, loss `0%`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** يستهلك الاختبار قدرًا كبيرًا من البيانات لفترة قصيرة، فتجنّبه على باقات محدودة. النتائج تعتمد على أقرب عقدة Cloudflare وقد تتأثر بازدحام اللحظة. تُرسَل حركة القياس إلى نطاقات Cloudflare (`speed.cloudflare.com`) فقط. يتطلب إنترنت.
**English:** The test briefly uses significant bandwidth, so avoid it on capped data plans. Results depend on the nearest Cloudflare node and can be affected by momentary congestion. Measurement traffic goes to Cloudflare domains (`speed.cloudflare.com`) only. Internet is required.
