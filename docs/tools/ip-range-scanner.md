# IP Range Scanner · فاحص مدى العناوين

> **Category / التصنيف:** Local Network / الشبكة المحلية  
> **Tool ID:** `ip-range-scanner`

---

## نظرة عامة · Overview
**بالعربي:** يمسح هذا الفاحص مدى عناوين IP (نطاق CIDR) ويحدّد المضيفين النشطين فيه عبر اختبار الوصول (ping)، مع قياس زمن الرحلة (RTT). يُعبّأ الحقل تلقائيًا بالشبكة الفرعية لجهازك حتى تبدأ الفحص فورًا. مفيد لاكتشاف كل الأجهزة المتصلة حتى تلك التي لا تُعلن عن نفسها عبر Bonjour.
**English:** This scanner sweeps a range of IP addresses (a CIDR block) and identifies the live hosts within it by probing reachability (ping), measuring the round‑trip time (RTT). The field is pre‑filled with your device's own subnet so you can scan immediately. Useful for finding every connected device, even ones that do not advertise themselves via Bonjour.

## كيف تعمل · How it works
**بالعربي:** تُوسِّع الأداة نطاق CIDR إلى قائمة عناوين المضيفين (باستثناء عنوان الشبكة والبث) عبر `SubnetEngine`، بحدٍّ أقصى `1024` مضيفًا. لكل مضيف تُجري اختبارًا متوازيًا (حتى 24 اتصالًا متزامنًا) يجمع بين طريقتين: (1) **ping عبر ICMP** باستخدام مقبس `SOCK_DGRAM`/`IPPROTO_ICMP` غير المميّز (لا يحتاج امتيازات root) مع مهلة 0.9 ثانية، فيعطي زمن رحلة حقيقيًا عندما يُسمح بـ ICMP؛ (2) **اختبار اتصال TCP** (`TCPHostProbe`) الذي يعثر على المضيفين حتى على الشبكات التي تحجب ICMP. يُعتبر المضيف حيًّا إذا نجحت أي من الطريقتين. رغم أن المقبس غير المميّز لا يحتاج entitlement، فإن مسح الشبكة الفرعية المحلية يستدعي صلاحية «الشبكة المحلية» في iOS.
**English:** The tool expands the CIDR range into a list of host addresses (excluding the network and broadcast addresses) via `SubnetEngine`, with a maximum of `1024` hosts. For each host it runs a parallel probe (up to 24 concurrent) combining two methods: (1) an **ICMP ping** using the unprivileged `SOCK_DGRAM`/`IPPROTO_ICMP` socket (no root entitlement needed) with a 0.9‑second timeout, giving a true round‑trip when ICMP is allowed; and (2) a **TCP‑connect probe** (`TCPHostProbe`) that still finds hosts on networks that filter ICMP entirely. A host is considered alive if either method succeeds. Although the unprivileged socket needs no entitlement, scanning the local subnet triggers the iOS Local Network permission.

## المدخلات · Inputs
**بالعربي:**
- **CIDR:** نطاق العناوين بصيغة `192.168.1.0/24`. إن كُتب عنوان بلا `/` يُفترض قناع `/24`. الحقل معبّأ مسبقًا بشبكة جهازك مثل `192.168.8.0/24`. لوحة المفاتيح أرقام ورموز بدون تصحيح تلقائي.
- زر «فحص» يبدأ المسح، وزر «إيقاف» يوقفه أثناء التشغيل.
**English:**
- **CIDR:** the address range in the form `192.168.1.0/24`. If an address is entered without a `/`, a `/24` mask is assumed. The field is pre‑filled with your device's subnet such as `192.168.8.0/24`. The keyboard is numbers‑and‑punctuation with autocorrect off.
- A "Scan" button starts the sweep, and a "Stop" button halts it while running.

## المخرجات · Outputs
**بالعربي:**
- **قسم التقدّم:** عدّاد `تم فحصه / الإجمالي` مثل `120 / 254`، شريط تقدّم، وشارة بعدد المضيفين النشطين مثل `8 up`.
- **قسم المضيفين:** قائمة بالعناوين الحيّة، كل صف يعرض أيقونة جهاز، العنوان (قابل للنسخ) مثل `192.168.8.10`، وزمن الرحلة بالمللي ثانية مثل `4 ms`.
- **السجل:** ملخّص لآخر عمليات الفحص مثل `192.168.8.0/24 — 8 up / 254`.
- عند وجود خطأ (نطاق غير صالح أو أكبر من 1024 مضيفًا) تُعرض رسالة خطأ.
**English:**
- **Progress section:** a `scanned / total` counter such as `120 / 254`, a progress bar, and a badge with the live host count such as `8 up`.
- **Hosts section:** a list of live addresses; each row shows a device icon, the address (copyable) such as `192.168.8.10`, and the round‑trip time in milliseconds such as `4 ms`.
- **History:** a summary of recent scans such as `192.168.8.0/24 — 8 up / 254`.
- On error (invalid range, or larger than 1024 hosts) an error message is shown.

## مثال تشغيل · Worked example
**بالعربي:** الحقل معبّأ بـ `192.168.8.0/24`. تضغط «فحص». يتقدّم العدّاد حتى `254 / 254`، وتظهر ثمانية مضيفين نشطين، منهم: `192.168.8.1` بزمن `2 ms` (الراوتر)، `192.168.8.10` بزمن `5 ms` (خادم NAS)، و`192.168.8.101` بزمن `1 ms` (جهازك). يُسجَّل `192.168.8.0/24 — 8 up / 254` في السجل.
**English:** The field is pre‑filled with `192.168.8.0/24`. You tap "Scan." The counter advances to `254 / 254`, and eight live hosts appear, among them: `192.168.8.1` at `2 ms` (the router), `192.168.8.10` at `5 ms` (a NAS), and `192.168.8.101` at `1 ms` (your device). `192.168.8.0/24 — 8 up / 254` is recorded in the history.

## ملاحظات وقيود · Notes & limitations
**بالعربي:**
- يستدعي مسح الشبكة الفرعية المحلية صلاحية **«الشبكة المحلية»** في iOS. لتفعيلها: **الإعدادات ← NetToolbox ← الشبكة المحلية**. بدونها تُرجع الأداة نتائج فارغة (لا يظهر أي مضيف).
- الحد الأقصى `1024` مضيفًا لكل فحص؛ النطاقات الأوسع من `/22` تُرفض برسالة «أكبر من اللازم».
- بعض الأجهزة تحجب كلًّا من ICMP واتصال TCP على المنافذ المُختبَرة فلا تظهر رغم كونها متصلة.
- قياس زمن الرحلة تقريبي؛ عند اكتشاف المضيف عبر TCP بدل ICMP يعكس الرقم زمن الاتصال لا صدى ping.
**English:**
- Scanning the local subnet invokes the iOS **Local Network** permission. Enable it via **Settings ← NetToolbox ← Local Network**. Without it the tool returns empty results (no host appears).
- The maximum is `1024` hosts per scan; ranges wider than `/22` are rejected with a "too large" message.
- Some devices block both ICMP and TCP‑connect on the probed ports and will not appear even though they are online.
- The RTT measurement is approximate; when a host is found via TCP rather than ICMP, the number reflects connect time rather than a ping echo.
