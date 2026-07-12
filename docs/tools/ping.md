# Ping · بينغ

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `ping`

---

## نظرة عامة · Overview
**بالعربي:** يقيس Ping قابلية الوصول وزمن الاستجابة إلى مضيف. يرسل صدى ICMP/ICMPv6 حقيقيًا، ويتحوّل تلقائيًا إلى قياس مصافحة TCP عند حجب ICMP على الشبكة. يوفّر خيارات احترافية: عدد الطلبات، الفترة بينها، المهلة، حجم الحمولة، وTTL.
**English:** Ping measures reachability and latency to a host. It sends real ICMP/ICMPv6 echoes and automatically switches to a TCP-handshake measurement when ICMP is filtered. It offers professional options: request count, period, timeout, payload size, and TTL.

## كيف تعمل · How it works
**بالعربي:** يحلّ `ICMPPingEngine` اسم المضيف أولًا (مع تفضيل IPv6 اختياريًا)، ثم يرسل صدى ICMP عبر مقبس `SOCK_DGRAM` غير المُميّز (النوع نفسه الذي تستخدمه SimplePing من Apple — بلا صلاحية خاصة ولا منفذ). لـ IPv4 يُستخدم `IPPROTO_ICMP` (نوع الطلب 8، الرد 0)، ولـ IPv6 يُستخدم `IPPROTO_ICMPV6` (الطلب 128، الرد 129). يُضبَط الـ TTL/hop-limit وحجم الحمولة (تُملأ بالحرف `a`) ومهلة الاستقبال.

**التحوّل إلى TCP:** إذا لم يُرَدّ على أول صدى ICMP (كثيرًا ما تُرشّح شبكات iOS/الخلوي ICMP)، يتحوّل التشغيل لبقية الجلسة إلى `TCPPingService` الذي يقيس زمن إتمام مصافحة TCP إلى منفذ احتياطي (افتراضيًا `443`). هذه المصافحة هي البديل الأصلي الموثوق على iOS لقياس الوصول والزمن.
**English:** `ICMPPingEngine` first resolves the hostname (optionally preferring IPv6), then sends an ICMP echo over the unprivileged `SOCK_DGRAM` socket (the same kind Apple's SimplePing uses — no special entitlement, no port). For IPv4 it uses `IPPROTO_ICMP` (request type 8, reply 0); for IPv6 it uses `IPPROTO_ICMPV6` (request 128, reply 129). The TTL/hop-limit, payload size (filled with the byte `a`), and receive timeout are set.

**TCP fallback:** if the very first ICMP echo goes unanswered (iOS/cellular networks often filter ICMP), the run switches for the rest of the session to `TCPPingService`, which times how long a TCP handshake to a fallback port (default `443`) takes. This handshake is the reliable native equivalent on iOS for measuring reachability and latency.

## المدخلات · Inputs
**بالعربي:**
- **المضيف:** اسم أو IP الهدف.
- **مستمر:** يستمر حتى الإيقاف بدل عدد ثابت.
- **عدد الطلبات:** الافتراضي `5` (حتى 1000).
- **الفترة:** الثواني بين الصدى (افتراضي `1`).
- **المهلة:** لكل صدى (افتراضي `2`ث).
- **حجم الحمولة:** بايت (افتراضي `56`).
- **TTL / hop-limit:** افتراضي `64`.
- **تفضيل IPv6.**
- **منفذ TCP الاحتياطي:** افتراضي `443`.
**English:**
- **Host:** target name or IP.
- **Continuous:** run until stopped instead of a fixed count.
- **Count:** default `5` (up to 1000).
- **Period:** seconds between echoes (default `1`).
- **Timeout:** per echo (default `2`s).
- **Payload size:** bytes (default `56`).
- **TTL / hop-limit:** default `64`.
- **Prefer IPv6.**
- **TCP fallback port:** default `443`.

## المخرجات · Outputs
**بالعربي:** العنوان المُحلَّل، وشارة تنبيه صفراء عند استخدام وضع TCP الاحتياطي. بطاقة الملخّص: نسبة الفقد، المستلَم/المرسَل، وأدنى/متوسط/أقصى/الانحراف المعياري (mdev) بالميلي ثانية، مع رسم Sparkline. قائمة المحاولات تعرض كل صدى (`#تسلسل` مع الزمن أو "انتهت المهلة"). ويُحفَظ سطر ملخّص في سجل الأداة.
**English:** The resolved address, and an amber badge when the TCP fallback mode is active. A summary card: loss percentage, received/sent, and min/avg/max/standard-deviation (mdev) in ms, with a Sparkline. An attempts list shows each echo (`#seq` with a time or "timeout"). A summary line is saved to the tool's own recent log.

## مثال تشغيل · Worked example
**بالعربي:** إدخال `1.1.1.1`، العدد `5` ← متوسط `12 ms`، أدنى `10`/أقصى `15`، فقد `0%`. على شبكة تحجب ICMP: يظهر تنبيه "وضع TCP" ويُقاس زمن المصافحة إلى المنفذ `443` بدلًا من ذلك.
**English:** Enter `1.1.1.1`, count `5` → avg `12 ms`, min `10`/max `15`, 0% loss. On an ICMP-filtering network: a "TCP mode" notice appears and the handshake time to port `443` is measured instead.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** على iOS لا تتوفّر مقابس ICMP الخام، لكن الأداة تستخدم مقبس ICMP بالبيانات (datagram) غير المميّز؛ وإن حُجب ICMP كليًا فالنتيجة تعكس زمن مصافحة TCP لا صدى ICMP الحقيقي. القياسات تعتمد على حالة الشبكة اللحظية. لا يُرسَل شيء لأي طرف ثالث — الفحص مباشر للهدف. لا يتطلب إذنًا خاصًا.
**English:** On iOS raw ICMP sockets are unavailable, but the tool uses the unprivileged ICMP datagram socket; if ICMP is fully blocked, the result reflects a TCP handshake time rather than a true ICMP echo. Measurements depend on momentary network conditions. Nothing is sent to any third party — the probe goes straight to the target. No special permission is required.
