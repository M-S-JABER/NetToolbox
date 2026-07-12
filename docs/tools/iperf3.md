# iperf3 Throughput · قياس الإنتاجية iperf3

> **Category / التصنيف:** Professional / احترافي  
> **Tool ID:** `iperf3`

---

## نظرة عامة · Overview
**بالعربي:** عميل iperf3 أصلي مبني على إطار Network.framework لقياس إنتاجية الشبكة (throughput) عبر TCP مقابل خادم `iperf3 -s`. يتصل على منفذ TCP رقم `5201` ويقيس السرعة بالميغابت/ثانية في اتجاه التنزيل أو الرفع، مع عرض حيّ للسرعة أثناء الاختبار.
**English:** A native iperf3 client built on Network.framework that measures network throughput over TCP against an `iperf3 -s` server. It connects on TCP port `5201` and measures speed in Mbit/s in the download or upload direction, with a live speed readout during the test.

## كيف تعمل · How it works
**بالعربي:** ينفّذ العميل مصافحة تحكّم iperf3 الكاملة عبر قناة TCP: يرسل الـ cookie (بطول 37 بايت) ثم يتبادل حالات البروتوكول: `PARAM_EXCHANGE` (يرسل معطيات الاختبار كـ JSON: الاتجاه العكسي، المدة، عدد التدفّقات)، `CREATE_STREAMS` (يفتح قنوات بيانات TCP)، `TEST_START`/`TEST_RUNNING`/`TEST_END`، ثم `EXCHANGE_RESULTS`/`DISPLAY_RESULTS`. في وضع التنزيل (reverse) يرسل الخادم البيانات والعميل يعدّ البايتات الواردة؛ في وضع الرفع يبثّ العميل كتل بيانات ويشغّل مؤقّت المدة. تُحسب السرعة محلياً من البايتات المنقولة مقسومة على الزمن المنقضي، وتُحدَّث حيّاً نحو مرتين في الثانية.
**English:** The client performs the full iperf3 control handshake over a TCP channel: it sends the cookie (37 bytes) then exchanges protocol states: `PARAM_EXCHANGE` (sends test parameters as JSON: reverse flag, duration, stream count), `CREATE_STREAMS` (opens TCP data channels), `TEST_START`/`TEST_RUNNING`/`TEST_END`, then `EXCHANGE_RESULTS`/`DISPLAY_RESULTS`. In download (reverse) mode the server sends data and the client counts inbound bytes; in upload mode the client blasts data blocks and runs a duration timer. Throughput is computed locally from transferred bytes over elapsed time, updated live roughly twice per second.

## المدخلات · Inputs
- **المضيف / Host:** عنوان خادم iperf3 · iperf3 server address.
- **المنفذ / Port:** الافتراضي `5201` (منفذ iperf3 القياسي) · Default `5201` (standard iperf3 port).
- **الاتجاه / Direction:** `download` (الخادم يرسل) أو `upload` (العميل يرسل) · `download` (server sends) or `upload` (client sends).
- **الثواني / Seconds:** مدة الاختبار، الافتراضي `10`، ضمن النطاق 1–60 · Test duration, default `10`, clamped to 1–60.
- **التدفّقات المتوازية / Parallel:** عدد تدفّقات TCP، الافتراضي `1`، ضمن النطاق 1–16 · Number of TCP streams, default `1`, clamped to 1–16.

## المخرجات · Outputs
**بالعربي:** أثناء التشغيل: قراءة حيّة كبيرة بالسرعة `Mbit/s` مع شريط تقدّم زمني. عند الانتهاء: السرعة النهائية، إجمالي البيانات المنقولة (بصيغة ثنائية مثل MiB)، المدة بالثواني، والاتجاه. عند الفشل تظهر رسالة (مثل "الخادم مشغول" إذا كان اختبار آخر جارياً).
**English:** While running: a large live `Mbit/s` readout with a time-progress bar. On completion: the final speed, total bytes transferred (binary units, e.g. MiB), the duration in seconds, and the direction. On failure a message is shown (e.g. "Server busy" if another test is running).

## مثال تشغيل · Worked example
**بالعربي:** الإدخال: المضيف `iperf.he.net`، المنفذ `5201`، الاتجاه `download`، المدة `10`، تدفّق واحد. النتيجة النموذجية: قراءة حيّة تتذبذب حول `93.4 Mbit/s`، وعند الانتهاء: `transferred ≈ 111 MiB`، `duration 10.0 s`، `direction download`.
**English:** Input: host `iperf.he.net`, port `5201`, direction `download`, duration `10`, one stream. Typical result: a live readout hovering around `93.4 Mbit/s`, and on completion: `transferred ≈ 111 MiB`, `duration 10.0 s`, `direction download`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** يدعم TCP فقط (لا UDP)، وبلا مصادقة (`--rsa` غير مدعوم)، ويستهدف خادم `iperf3 -s` عادياً على المنفذ الافتراضي. إذا كان الخادم يشغّل اختباراً آخر يرفض الاتصال. تُحسب السرعة من عدّاد البايتات المحلي وليس من نتائج الخادم. المدة مقيّدة بـ 1–60 ثانية والتوازي بـ 1–16 تدفّقاً. النتائج تتأثر بجودة اتصال الجوّال/الواي-فاي.
**English:** It supports TCP only (no UDP), has no authentication (`--rsa` unsupported), and targets a plain `iperf3 -s` server on the default port. If the server is running another test it refuses the connection. Speed is computed from the local byte counter, not the server's results. Duration is clamped to 1–60 seconds and parallelism to 1–16 streams. Results are affected by the quality of the cellular/Wi-Fi link.
