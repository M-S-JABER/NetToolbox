# Traceroute · تتبّع المسار

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `traceroute`

---

## نظرة عامة · Overview
**بالعربي:** يتتبّع Traceroute مسار الشبكة (القفزات/hops) إلى مضيف، مُظهرًا كل موجّه على الطريق وزمن استجابته. الموجّهات التي لا تردّ تظهر كـ `*`. وإذا حُجب ICMP كليًا، يستخدم فحص TCP لتأكيد الوصول ومسافة القفزات بدلًا من ذلك.
**English:** Traceroute traces the network path (hops) to a host, showing each router along the way and its round-trip time. Routers that don't reply show as `*`. If ICMP is fully blocked, a TCP probe confirms reachability and hop distance instead.

## كيف تعمل · How it works
**بالعربي:** يستخدم `ICMPTraceroute` مقبس ICMP بالبيانات (`SOCK_DGRAM`/`IPPROTO_ICMP`) غير المميّز — النوع نفسه الذي تستخدمه SimplePing من Apple، فلا حاجة لصلاحية خاصة. يُرسَل صدى ICMP بقيمة TTL متزايدة: تردّ الموجّهات الوسيطة برسالة "TTL انتهى" (Time Exceeded)، ويردّ الهدف النهائي بـ "Echo Reply". يكتشف الكود ما إذا كان رأس IPv4 (20 بايت) ما زال ملحقًا بالرد فيتجاوزه ليقرأ نوع ICMP الصحيح.

**التوازي:** بدل السير قفزةً قفزة (ما يُبطئ التتبّع عند كل موجّه صامت)، يفحص كل قيم TTL دفعةً واحدة عبر `TaskGroup`، مع إعادة محاولة كل قفزة حتى `retries` مرات، وتُبثّ النتائج فور ورودها.

**التحوّل إلى TCP:** إذا لم يُنتج ICMP أي عنوان مفيد (كل القفزات صامتة ولم يُبلَغ الوصول)، يشغّل `TCPTraceProbe.trace` فحص وصول TCP يعطي مسافة القفزات وزمن RTT حقيقيًا حين يتعذّر تسمية الموجّهات.
**English:** `ICMPTraceroute` uses the unprivileged ICMP datagram socket (`SOCK_DGRAM`/`IPPROTO_ICMP`) — the same kind Apple's SimplePing uses, so no special entitlement is needed. It sends ICMP echoes with increasing TTL: intermediate routers reply with "Time Exceeded", and the final destination replies with an "Echo Reply". The code detects whether a 20-byte IPv4 header is still attached to the reply and skips past it to read the correct ICMP type.

**Parallelism:** instead of walking hop by hop (which stalls on every silent router), it probes all TTL values at once via a `TaskGroup`, retrying each hop up to `retries` times, and streams results as they arrive.

**TCP fallback:** if ICMP produces no usable address (all hops silent and the destination never reached), `TCPTraceProbe.trace` runs a TCP reachability probe that yields a real hop distance and RTT when routers can't be named.

## المدخلات · Inputs
**بالعربي:**
- **المضيف:** اسم أو IP الهدف.
- **المهلة:** لكل قفزة بالثواني (افتراضي `2`، بحدّ أدنى 0.3).
- **إعادة المحاولة (retry):** عدد الفحوص لكل قفزة (افتراضي `1`، حتى 5).
- **أقصى قفزات:** افتراضي `20` (حتى 64).
**English:**
- **Host:** target name or IP.
- **Timeout:** per hop in seconds (default `2`, min 0.3).
- **Retry:** probes per hop (default `1`, up to 5).
- **Max hops:** default `20` (up to 64).

## المخرجات · Outputs
**بالعربي:** قائمة القفزات مرقّمة بـ TTL: عنوان الموجّه (أو `*` عند عدم الرد) وزمن RTF بالميلي ثانية، مع شارة "تم الوصول" عند القفزة النهائية. عند التحوّل إلى TCP تظهر بطاقة "وصول عبر TCP" فيها المنفذ وعدد القفزات وزمن RTT. ويُحفَظ سطر في سجل الأداة (`الهدف — N قفزات ✓`).
**English:** A hop list numbered by TTL: the router address (or `*` on no reply) and RTT in ms, with a "reached" badge on the final hop. When it falls back to TCP, a "reachable via TCP" card shows the port, hop count, and RTT. A line is saved to the tool's log (`target — N hops ✓`).

## مثال تشغيل · Worked example
**بالعربي:** إدخال `8.8.8.8` ← قفزات متتالية: `1 192.168.1.1 1.2 ms`، `2 * `، `3 10.x.x.x 8.4 ms` … حتى `dns.google` بشارة "تم الوصول". على شبكة تحجب ICMP: بطاقة "وصول عبر TCP :443" مع مثلًا 8 قفزات و42 ms.
**English:** Enter `8.8.8.8` → successive hops: `1 192.168.1.1 1.2 ms`, `2 *`, `3 10.x.x.x 8.4 ms` … ending at `dns.google` with a "reached" badge. On an ICMP-filtering network: a "reachable via TCP :443" card with, say, 8 hops and 42 ms.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** على iOS لا تتوفّر مقابس ICMP الخام؛ تستخدم الأداة مقبس ICMP بالبيانات، وإن حُجب كليًا فالنتيجة هي فحص وصول TCP لا مسار ICMP كامل. القفزات الصامتة قد تعني موجّهات لا تردّ لا انقطاعًا. الفحص مباشر للهدف دون طرف ثالث. افحص فقط أهدافًا مصرّحًا لك بها.
**English:** On iOS raw ICMP sockets are unavailable; the tool uses the ICMP datagram socket, and if it's fully blocked the result is a TCP reachability probe rather than a full ICMP path. Silent hops may mean routers that don't reply, not an outage. The probe goes straight to the target with no third party. Only probe targets you're authorized to test.
