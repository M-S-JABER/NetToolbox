# DNS Reliability Monitor · مراقب موثوقية DNS

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `dns-reliability`

---

## نظرة عامة · Overview
**بالعربي:** مراقب مستمر يُكرّر استعلام DNS واحدًا على فترات منتظمة ويقيس زمن الاستجابة ومعدّل النجاح مع مرور الوقت. مفيد لرصد التذبذب (jitter) وحالات الانقطاع المتقطّعة في خادم DNS. يعمل عبر UDP مباشرة إلى الخادم على المنفذ `53`.

**English:** A continuous monitor that repeats a single DNS query at regular intervals and measures response time and success rate over time. Useful for spotting jitter and intermittent drops in a DNS server. It works over UDP directly to the server on port `53`.

## كيف تعمل · How it works
**بالعربي:** في حلقة متواصلة، تستخدم الأداة `UDPDNSResolver` (نفس مسار أداة DNS Lookup: بناء استعلام wire-format وإرساله عبر `UDPExchange` إلى `server:53` بمهلة `5` ثوانٍ). تقيس زمن الرحلة بساعة `ContinuousClock` بدقّة الملّي ثانية، وتُسجّل كل محاولة كـ «نجاح مع زمن» أو «إسقاط». يحسب المحرّك النقيّ `DNSReliabilityEngine` إحصاءات تراكمية: معدّل النجاح، أدنى/متوسط/أعلى زمن، التذبذب (متوسط الفرق المطلق بين الأزمنة المتتالية)، عدد نوبات الإسقاط، أطول سلسلة إسقاط متتالية، وعدد الردود «البطيئة» التي تتجاوز العتبة. يحتفظ بآخر `200` عيّنة كحد أقصى.

**English:** In a continuous loop, the tool uses `UDPDNSResolver` (the same path as DNS Lookup: build a wire-format query and send it via `UDPExchange` to `server:53` with a `5`-second timeout). It times the round-trip with a `ContinuousClock` in milliseconds, recording each attempt as a "success with latency" or a "drop". The pure `DNSReliabilityEngine` computes running stats: success rate, min/avg/max latency, jitter (mean absolute delta between consecutive latencies), number of drop episodes, longest consecutive drop streak, and the count of "slow" responses exceeding the threshold. It keeps at most the last `200` samples.

## المدخلات · Inputs
- **Host / المضيف:** اسم النطاق للاستعلام عنه المتكرّر · the domain to repeatedly query.
- **Server / الخادم:** خادم DNS المستهدف، الافتراضي `1.1.1.1` · target DNS server (default `1.1.1.1`).
- **Type / النوع:** نوع السجل من: `A`, `NS`, `CNAME`, `SOA`, `PTR`, `MX`, `TXT`, `AAAA`.
- **Interval / الفاصل:** الفترة بين المحاولات بالثواني (الحد الأدنى `0.3`، الافتراضي `1.0`) · seconds between attempts.
- **Threshold / العتبة:** حد «البطء» بالملّي ثانية (الافتراضي `200`؛ `0` أو فارغ يعطّله) · slow-response threshold in ms.

## المخرجات · Outputs
**بالعربي:** بطاقة ملخّص فيها شارة حالة (`stable` / `slow` / `unstable`) ومعدّل النجاح، وعدّاد العيّنات `successes/total`، وعدد نوبات الإسقاط وأطول سلسلة، ونطاق الأزمنة والمتوسط والتذبذب. بالإضافة إلى مخطّط شعري (sparkline) للأزمنة (الإسقاط يظهر كهبوط إلى الصفر)، وقائمة بآخر 12 محاولة بحالتها.

**English:** A summary card with a status badge (`stable` / `slow` / `unstable`) and success rate, a `successes/total` sample counter, drop episodes and longest streak, plus latency range, average, and jitter. Also a sparkline of latencies (a drop renders as a dip to zero) and a list of the last 12 attempts with their status.

## مثال تشغيل · Worked example
**بالعربي:** المضيف `apple.com`، الخادم `8.8.8.8`، الفاصل `1.0`، العتبة `200`. بعد 60 عيّنة قد يظهر: معدّل نجاح `100%`، نطاق زمن `18–45 ms`، متوسط `27 ms`، تذبذب `6 ms`، صفر نوبات إسقاط، وحالة `stable`.

**English:** Host `apple.com`, server `8.8.8.8`, interval `1.0`, threshold `200`. After 60 samples it might show: success rate `100%`, latency range `18–45 ms`, average `27 ms`, jitter `6 ms`, zero drop episodes, and a `stable` status.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** المراقبة تعمل طالما بقيت الأداة نشطة وتستهلك حركة شبكة مستمرة وبطارية؛ الحد الأقصى `200` عيّنة يُنسي الأقدم. يتطلّب سماح الشبكة بحركة UDP على المنفذ `53`. الأزمنة تشمل زمن مصافحة الشبكة الكامل وقد تتأثّر بحمل الجهاز نفسه. تبقى الجلسة قائمة عبر التنقّل في التطبيق حتى تُوقفها يدويًا.

**English:** Monitoring runs as long as the tool is active and consumes continuous network traffic and battery; the `200`-sample cap discards the oldest. Requires the network to permit UDP on port `53`. Latencies include the full network round-trip and can be affected by device load. The session persists across in-app navigation until you stop it manually.
