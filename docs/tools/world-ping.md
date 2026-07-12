# World Ping · بينغ عالمي

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `world-ping`

---

## نظرة عامة · Overview
**بالعربي:** يقيس "البينغ العالمي" الوصول إلى هدف من مواقع مِسبار (probes) موزّعة حول العالم، لا من جهازك. كل صفّ يعرض موقع المِسبار وشبكته وزمن الاستجابة (أدنى/متوسط/أقصى) ونسبة الفقد — مفيد لمعرفة كيف يُرى موقعك أو خادمك من قارات مختلفة.
**English:** World Ping measures reachability to a target from probe locations distributed around the globe, not from your device. Each row shows the probe's location, network, latency (min/avg/max), and loss — useful to see how your site or server appears from different continents.

## كيف تعمل · How it works
**بالعربي:** تستخدم الأداة شبكة globalping.io المجانية بلا مفتاح عبر واجهة `https://api.globalping.io/v1/measurements` على HTTPS منفذ `443`. الخطوات:
1. **البدء:** طلب `POST` بجسم JSON `{ "type": "ping", "target": ..., "limit": ..., "locations": [{"magic":"world"}], "measurementOptions": {"packets": ...} }` فيعيد معرّف القياس `id`.
2. **الاستطلاع (poll):** طلبات `GET` متكرّرة إلى `.../measurements/<id>` كل ثانية (حتى 25 مرة) حتى تصبح الحالة `finished`، وتُحدَّث النتائج تدريجيًا.

المسابير البعيدة هي التي تُنفّذ البينغ الفعلي (ICMP لديها)، فلا يوجد ICMP محلي على جهازك إطلاقًا.
**English:** The tool uses the free, key-less globalping.io network via `https://api.globalping.io/v1/measurements` over HTTPS on port `443`. Steps:
1. **Start:** a `POST` with JSON body `{ "type": "ping", "target": ..., "limit": ..., "locations": [{"magic":"world"}], "measurementOptions": {"packets": ...} }` returns a measurement `id`.
2. **Poll:** repeated `GET` requests to `.../measurements/<id>` every second (up to 25 times) until the status is `finished`, updating results incrementally.

The remote probes perform the actual pinging (their own ICMP), so there is no local ICMP on your device at all.

## المدخلات · Inputs
**بالعربي:**
- **المضيف:** اسم أو IP الهدف.
- **الحد (limit):** عدد المسابير، افتراضي `8` (يُقيَّد بين 1 و20).
- **الحزم (packets):** عدد الحزم لكل مِسبار، افتراضي `4` (يُقيَّد بين 1 و16).
**English:**
- **Host:** target name or IP.
- **Limit:** number of probes, default `8` (clamped 1–20).
- **Packets:** packets per probe, default `4` (clamped 1–16).

## المخرجات · Outputs
**بالعربي:** قائمة صفوف، كل صف: الموقع (مدينة، دولة)، اسم الشبكة، الفقد بصيغة `مستلَم/مرسَل · نسبة%` (أخضر عند 0%)، وزمن الاستجابة `أدنى / متوسط / أقصى ms`. تُبثّ النتائج أثناء اكتمال القياس.
**English:** A list of rows, each with: location (city, country), network name, loss as `received/sent · percent%` (green at 0%), and latency `min / avg / max ms`. Results stream in as the measurement completes.

## مثال تشغيل · Worked example
**بالعربي:** الهدف `1.1.1.1`، الحد `8` ← London `2/3 · 0% · 1 / 3 / 4 ms`، Tokyo `... 2 ms`، São Paulo `... 4 ms`، وهكذا لمسابير أخرى.
**English:** Target `1.1.1.1`, limit `8` → London `2/3 · 0% · 1 / 3 / 4 ms`, Tokyo `... 2 ms`, São Paulo `... 4 ms`, and so on for other probes.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** يعتمد كليًا على توفّر شبكة globalping.io العامة وقد يتأخّر أو يفشل إن كانت مشغولة. يُرسَل الهدف الذي تكتبه إلى `api.globalping.io`. يتطلب إنترنت. الاستطلاع محدود بـ 25 محاولة (نحو 25 ثانية) ثم يتوقف. لا ICMP على جهازك.
**English:** It depends entirely on the public globalping.io network and may be slow or fail when it's busy. The target you type is sent to `api.globalping.io`. Internet is required. Polling is capped at 25 attempts (~25 seconds) then stops. No ICMP runs on your device.
