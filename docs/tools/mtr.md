# MTR Path Analysis · تحليل المسار MTR

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `mtr`

---

## نظرة عامة · Overview
**بالعربي:** MTR هو تتبّع مسار متواصل يجمع بين إحصائيات فقد الحزم وزمن الاستجابة لكل قفزة عبر جولات متكرّرة. لكل قفزة يعرض آخر/متوسط/أفضل/أسوأ زمن ونسبة الفقد ورقم النظام المستقل (AS) للموجّه — يمنحك صورة أوضح لمكان المشكلة على الطريق.
**English:** MTR is a continuous traceroute that combines per-hop packet loss and latency across repeated rounds. For each hop it shows last/avg/best/worst latency, loss percentage, and the router's origin AS — giving a clearer picture of where along the path a problem lies.

## كيف تعمل · How it works
**بالعربي:** يستخدم MTR محرّك التتبّع نفسه `ICMPTraceroute` (مقبس ICMP بالبيانات `SOCK_DGRAM`/`IPPROTO_ICMP` غير المميّز، بلا صلاحية خاصة). في كل جولة يفحص كل قيم TTL دفعةً واحدة عبر `TaskGroup`، ثم يُجمِّع النتائج في إحصائيات جارية لكل قفزة عبر `MTREngine.record` (يزيد المُرسَل، ويحدّث المستلَم والأدنى/الأقصى والمجموع للمتوسط). يتكرّر ذلك كل ثانية حتى الإيقاف. تُقصَّر قائمة القفزات عند أول قفزة تصل للهدف.

**إثراء AS:** عند تفعيل الخيار، يعكس عنوان IPv4 لكل قفزة ويستعلم عن `<معكوس>.origin.asn.cymru.com` من نوع TXT عبر `UDPDNSResolver` (DNS خام على المنفذ `53`، الخادم `1.1.1.1`)، ثم يستخرج رقم AS من رد Team Cymru (مثل `AS13335`).
**English:** MTR uses the same tracer engine `ICMPTraceroute` (the unprivileged ICMP datagram socket `SOCK_DGRAM`/`IPPROTO_ICMP`, no special entitlement). Each round it probes all TTL values at once via a `TaskGroup`, then folds results into running per-hop stats via `MTREngine.record` (incrementing sent, and updating received, min/max, and the sum for the average). This repeats every second until stopped. The hop list is trimmed at the first hop that reaches the target.

**AS enrichment:** when enabled, it reverses each hop's IPv4 address and queries `<reversed>.origin.asn.cymru.com` as a TXT record via `UDPDNSResolver` (raw DNS on port `53`, server `1.1.1.1`), then extracts the AS number from the Team Cymru reply (e.g. `AS13335`).

## المدخلات · Inputs
**بالعربي:**
- **المضيف:** اسم أو IP الهدف.
- **أقصى قفزات:** افتراضي `20` (حتى 64).
- **المهلة:** بالثواني لكل فحص (افتراضي `1.5`، بحدّ أدنى 0.3؛ تقبل الفاصلة كنقطة عشرية).
- **بحث AS:** مفتاح لتفعيل استعلام رقم النظام المستقل (مُفعَّل افتراضيًا).
**English:**
- **Host:** target name or IP.
- **Max hops:** default `20` (up to 64).
- **Timeout:** seconds per probe (default `1.5`, min 0.3; accepts comma as decimal point).
- **ASN lookup:** a toggle to enable origin-AS lookup (on by default).

## المخرجات · Outputs
**بالعربي:** جدول قفزات متجدّد لكل جولة: رقم القفزة، عنوان الموجّه (أو `* * *`)، شارة "تم الوصول" للنهائية، ورقم AS (بلون مميّز). ولكل قفزة: نسبة الفقد (ملوّنة حسب الشدة)، وآخر/متوسط/أفضل/أسوأ زمن بالميلي ثانية. عدّاد الجولات يظهر أعلى الشاشة، وزر تصدير CSV متاح.
**English:** A live hop table refreshed each round: hop number, router address (or `* * *`), a "reached" badge for the final hop, and the AS number (in an accent color). Per hop: loss percentage (colored by severity) and last/avg/best/worst latency in ms. A rounds counter shows at the top, and a CSV export button is available.

## مثال تشغيل · Worked example
**بالعربي:** إدخال `apple.com` مع تفعيل بحث AS ← جدول: القفزة 1 `192.168.1.1` فقد `0%` متوسط `2 ms`؛ القفزة 5 `AS3356` فقد `0%` متوسط `14 ms`؛ … حتى قفزة الهدف بعلامة "تم الوصول". يتراكم عدد الجولات مع الوقت ويمكن تصدير CSV.
**English:** Enter `apple.com` with ASN lookup on → table: hop 1 `192.168.1.1` loss `0%` avg `2 ms`; hop 5 `AS3356` loss `0%` avg `14 ms`; … up to the destination hop marked "reached". The rounds count grows over time, and CSV can be exported.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** على iOS لا تتوفّر مقابس ICMP الخام؛ يعتمد MTR على مقبس ICMP بالبيانات، وقد لا تظهر بعض القفزات إن حجبت الشبكة ICMP (بخلاف Traceroute، لا يوجد هنا تحوّل صريح إلى فحص TCP). استعلام AS يعتمد على خدمة Team Cymru عبر DNS إلى `1.1.1.1`. التشغيل متواصل ويستهلك بطارية وبيانات حتى تضغط "إيقاف". افحص فقط أهدافًا مصرّحًا لك بها.
**English:** On iOS raw ICMP sockets are unavailable; MTR relies on the ICMP datagram socket, and some hops may not appear if the network filters ICMP (unlike Traceroute, there is no explicit TCP fallback here). AS lookup depends on the Team Cymru service via DNS to `1.1.1.1`. The run is continuous and uses battery and data until you tap Stop. Only probe targets you're authorized to test.
