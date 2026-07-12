import Foundation

extension ToolHelp {
    static let diagnosticsHelpB: [String: ToolHelpContent] = [
        "http-timing": ToolHelpContent(
            overview: LocalizedText(
                en: "Runs a single HTTP/HTTPS request and breaks it into precise phases (DNS, connect, TLS, request, wait, download) to draw a mini timing waterfall showing where time is spent. It runs entirely on-device using the system network stack.",
                ar: "تنفّذ طلب HTTP/HTTPS واحدًا وتفكّكه إلى مراحل زمنية دقيقة (DNS، الاتصال، TLS، الطلب، الانتظار، التنزيل) لترسم شلالًا زمنيًا يوضّح أين يُقضى الوقت. تعمل محليًا بالكامل عبر مكدّس الشبكة في النظام."
            ),
            howItWorks: LocalizedText(
                en: "It issues the request through an ephemeral URLSession (no caching) with a 20-second timeout and captures URLSessionTaskMetrics. Each phase is computed as a time delta in milliseconds, unavailable phases are omitted, and https is assumed when the scheme is missing.",
                ar: "تُرسل الطلب عبر URLSession مؤقتة (بلا تخزين) بمهلة 20 ثانية وتلتقط URLSessionTaskMetrics. تُحسب كل مرحلة كفرق زمني بالمللي ثانية، وتُحذف المراحل غير المتاحة، ويُفترض https إن غاب البروتوكول."
            ),
            example: LocalizedText(
                en: "Input « https://apple.com »: status 200, total 312 ms, with phases such as DNS 18 ms, Connect 40 ms, TLS 65 ms, Wait (TTFB) 150 ms, and Download 38 ms.",
                ar: "المدخل « https://apple.com »: الحالة 200، الإجمالي 312 ms، بمراحل مثل DNS 18 ms وConnect 40 ms وTLS 65 ms وWait (TTFB) 150 ms وDownload 38 ms."
            ),
            notes: LocalizedText(
                en: "It measures a single request, so numbers vary between runs with the network and server-side caching. The TLS phase appears only for secure connections, and DNS or Connect may be absent when an existing connection is reused.",
                ar: "تقيس طلبًا واحدًا فقط، فتتفاوت الأرقام بين المحاولات بحسب الشبكة والتخزين المؤقت لدى الخادم. تظهر مرحلة TLS للاتصالات المؤمّنة فقط، وقد تغيب DNS أو Connect عند إعادة استخدام اتصال قائم."
            )
        ),
        "speed-test": ToolHelpContent(
            overview: LocalizedText(
                en: "Measures latency, jitter, download and upload throughput, plus bufferbloat (latency growth under load) and probe loss. It runs against the same open Cloudflare infrastructure that backs speed.cloudflare.com.",
                ar: "يقيس زمن الاستجابة والاهتزاز (jitter) وسرعتي التنزيل والرفع، إضافةً إلى bufferbloat (زيادة زمن الاستجابة تحت الحِمل) ونسبة فقد الحزم. يعمل على بنية Cloudflare المفتوحة نفسها التي يقوم عليها موقع speed.cloudflare.com."
            ),
            howItWorks: LocalizedText(
                en: "The CloudflareSpeedEngine streams incremental results over HTTPS on port 443: metadata from /meta, 12 latency probes to __down?bytes=0, an 8-second download and a 6-second upload, then bufferbloat graded from latency under load. There is no ICMP; every measurement is over HTTPS.",
                ar: "يبثّ محرّك CloudflareSpeedEngine نتائج تدريجية عبر HTTPS على المنفذ 443: بيانات وصفية من /meta، و12 عيّنة زمن استجابة إلى __down?bytes=0، وتنزيل 8 ثوانٍ ورفع 6 ثوانٍ، ثم تقدير bufferbloat من زمن الاستجابة تحت الحِمل. لا يوجد ICMP؛ كل القياسات عبر HTTPS."
            ),
            example: LocalizedText(
                en: "Tap Start: server STC Riyadh via colo JED; download 248.6 Mbps, upload 41.3 Mbps, ping 12 ms, jitter 3 ms, bufferbloat A at +18 ms, loss 0%.",
                ar: "اضغط بدء: الخادم STC Riyadh عبر عقدة JED؛ تنزيل 248.6 Mbps ورفع 41.3 Mbps وping 12 ms وjitter 3 ms وbufferbloat A بزيادة +18 ms وفقد 0%."
            ),
            notes: LocalizedText(
                en: "The test briefly uses significant bandwidth, so avoid it on capped data plans. Results depend on the nearest Cloudflare node; measurement traffic goes to speed.cloudflare.com only, and internet is required.",
                ar: "يستهلك الاختبار قدرًا كبيرًا من البيانات لفترة قصيرة، فتجنّبه على الباقات المحدودة. تعتمد النتائج على أقرب عقدة Cloudflare، وتُرسَل حركة القياس إلى speed.cloudflare.com فقط، ويتطلب إنترنت."
            )
        ),
        "uptime": ToolHelpContent(
            overview: LocalizedText(
                en: "Checks a list of URLs in one batch and shows which are up and which are down, along with each one's response time. A mini on-demand monitor that runs locally with no external monitoring server.",
                ar: "يفحص قائمة روابط دفعة واحدة ويبيّن أيها متاح وأيها متعذّر مع زمن الاستجابة لكل رابط. مراقبة لحظية مصغّرة تعمل محليًا دون خادم مراقبة خارجي."
            ),
            howItWorks: LocalizedText(
                en: "The list is split on newlines, commas, or spaces with duplicates removed. Each URL (https prepended if missing) gets a GET via an ephemeral URLSession with a 12-second timeout, all run concurrently; a status of 200 to 399 counts as up, and any error or timeout as down.",
                ar: "تُقسَّم القائمة على الأسطر أو الفواصل أو المسافات مع إزالة التكرارات. يُرسَل لكل رابط (يُضاف https إن غاب) طلب GET عبر URLSession مؤقتة بمهلة 12 ثانية وكلها بالتوازي؛ يُعدّ الرمز 200 إلى 399 متوفرًا وأي خطأ أو مهلة متعذّرًا."
            ),
            example: LocalizedText(
                en: "Input « apple.com, github.com, no-such-host.invalid »: apple.com green 200 · 210 ms, github.com green 200 · 180 ms, no-such-host.invalid red down.",
                ar: "المدخل « apple.com, github.com, no-such-host.invalid »: apple.com أخضر 200 · 210 ms، وgithub.com أخضر 200 · 180 ms، وno-such-host.invalid أحمر down."
            ),
            notes: LocalizedText(
                en: "The check is a one-shot snapshot, not continuous monitoring; there are no alerts or scheduling. It relies only on the HTTP status code, so a site returning a 4xx error page may show as down even though the server is running.",
                ar: "الفحص لحظي وليس مراقبة مستمرة؛ لا تنبيهات ولا جدولة. يعتمد على رمز الحالة فقط، فقد يظهر موقع يعيد صفحة خطأ 4xx كمتعذّر رغم أن الخادم يعمل."
            )
        ),
        "ssl-checker": ToolHelpContent(
            overview: LocalizedText(
                en: "Performs a TLS handshake, inspects the certificate and trust chain, detects supported TLS versions, and assigns a security grade. All of it runs locally using the Network and Security frameworks, without an external service like SSL Labs.",
                ar: "يُجري مصافحة TLS ويفحص الشهادة وسلسلة الثقة ويكتشف إصدارات TLS المدعومة ثم يمنح درجة أمان. كل ذلك محليًا عبر أطر Network وSecurity دون خدمة خارجية مثل SSL Labs."
            ),
            howItWorks: LocalizedText(
                en: "It opens a TLS connection via NWConnection to the host and port (default 443), reads the certificate chain from SecTrust, and parses validity dates and SANs from the DER. It probes TLS 1.0 to 1.3 separately, then TLSAudit.grade applies heuristics: expired, weak key, or no modern protocol yield F, untrusted yields T, and TLS 1.3 with a strong trusted certificate reaches A+.",
                ar: "يفتح اتصال TLS عبر NWConnection إلى المضيف والمنفذ (افتراضيًا 443)، ويقرأ سلسلة الشهادات من SecTrust، ويحلّل تواريخ الصلاحية والأسماء البديلة (SAN) من ترميز DER. يفحص TLS 1.0 حتى 1.3 كلًّا على حدة، ثم يطبّق TLSAudit.grade قواعد استدلالية: المنتهية أو المفتاح الضعيف أو غياب بروتوكول حديث = F، وغير الموثوق = T، وTLS 1.3 مع شهادة قوية موثوقة = A+."
            ),
            example: LocalizedText(
                en: "Input « apple.com » on port 443: grade A+, protocols TLS 1.2 · TLS 1.3, certificate trusted, 70d remaining, key EC 256-bit.",
                ar: "المدخل « apple.com » على المنفذ 443: الدرجة A+، البروتوكولات TLS 1.2 · TLS 1.3، الشهادة موثوقة، الأيام المتبقية 70d، المفتاح EC 256-bit."
            ),
            notes: LocalizedText(
                en: "The grade is heuristic and scoped to what iOS can natively observe, with no detailed cipher-suite inspection. Legacy TLS 1.0/1.1 probing uses raw wire values, and the connection is direct from your device.",
                ar: "الدرجة تقريبية ومقصورة على ما يمكن لـ iOS ملاحظته أصلًا، دون فحص تفصيلي لمجموعات التشفير. يستخدم فحص TLS 1.0/1.1 القديم قيمًا خام، والاتصال مباشر من جهازك."
            )
        ),
        "cert-expiry": ToolHelpContent(
            overview: LocalizedText(
                en: "Watches a list of hosts and shows how many days remain before each one's TLS certificate expires, with a color-coded status. It opens a direct TLS connection to port 443 and inspects the certificate locally, with no external service.",
                ar: "تراقب قائمة مضيفين وتُظهر كم يومًا يتبقّى قبل انتهاء شهادة TLS لكل منهم مع تصنيف لوني للحالة. تفتح اتصال TLS مباشرًا بالمنفذ 443 وتفحص الشهادة محليًا دون أي خدمة خارجية."
            ),
            howItWorks: LocalizedText(
                en: "For each host it connects via NWConnection to port 443, captures the certificate chain from SecTrust, and parses notBefore/notAfter from the DER since iOS has no API for it. CertExpiryEngine.level buckets days remaining: over 30 = ok, under 30 = warning, under 15 = critical, below zero = expired. Host checks run concurrently.",
                ar: "لكل مضيف تتصل عبر NWConnection بالمنفذ 443، وتلتقط سلسلة الشهادات من SecTrust، وتحلّل notBefore وnotAfter من ترميز DER لأن iOS لا يوفّر واجهة لذلك. يصنّف CertExpiryEngine.level الأيام المتبقية: أكثر من 30 = سليم، أقل من 30 = تحذير، أقل من 15 = حرِج، أقل من صفر = منتهية. وتُنفَّذ الفحوص بالتوازي."
            ),
            example: LocalizedText(
                en: "Add « apple.com »: the tool connects on 443, reads notAfter = 2026-09-20, and shows a badge like 70d in green (healthy).",
                ar: "أضف « apple.com »: تتصل الأداة على 443، وتقرأ notAfter = 2026-09-20، فتعرض بشارة مثل 70d باللون الأخضر (سليم)."
            ),
            notes: LocalizedText(
                en: "Checks are limited to port 443 and report certificate data even if the system does not trust it. DER date parsing assumes standard X.509, the list can be exported as CSV, and the connection is direct from your device.",
                ar: "الفحص مقصور على المنفذ 443 ويعرض بيانات الشهادة حتى لو لم يثق بها النظام. يفترض تحليل تواريخ DER شهادات X.509 قياسية، ويمكن تصدير القائمة كملف CSV، والاتصال مباشر من جهازك."
            )
        ),
        "cert-transparency": ToolHelpContent(
            overview: LocalizedText(
                en: "Searches Certificate Transparency logs for every TLS certificate ever publicly issued for a domain. Useful for spotting forgotten or rogue certificates and hidden subdomains, via the free crt.sh service with no API key required.",
                ar: "تبحث في سجلات شفافية الشهادات عن كل شهادة TLS صُدرت علنًا لنطاق معيّن. مفيدة لاكتشاف الشهادات المنسيّة أو المارقة والنطاقات الفرعية المخفيّة، عبر خدمة crt.sh المجانية دون أي مفتاح."
            ),
            howItWorks: LocalizedText(
                en: "It sends a GET to https://crt.sh/?q=<domain>&output=json on port 443 with a 20-second timeout. The JSON is decoded into rows (CN, SANs, issuer, validity dates), duplicates removed by a composite key, the issuer shortened to its CN part, and up to 50 entries are shown.",
                ar: "تُرسِل طلب GET إلى https://crt.sh/?q=<domain>&output=json على المنفذ 443 بمهلة 20 ثانية. تُفكَّك استجابة JSON إلى صفوف (الاسم الشائع، والأسماء البديلة، والمُصدِر، وتواريخ الصلاحية)، وتُزال التكرارات بمفتاح مركّب، ويُختصر المُصدِر إلى جزء CN، ويُعرَض حتى 50 إدخالًا."
            ),
            example: LocalizedText(
                en: "Domain « github.com »: entries such as common name github.com, issuer Sectigo ECC Domain Validation Secure Server CA, range 2023-02-14 → 2024-03-14, and a name list including www.github.com.",
                ar: "النطاق « github.com »: إدخالات مثل الاسم الشائع github.com، والمُصدِر Sectigo ECC Domain Validation Secure Server CA، والنطاق 2023-02-14 → 2024-03-14، وقائمة أسماء تشمل www.github.com."
            ),
            notes: LocalizedText(
                en: "Requires an internet connection, and crt.sh can be slow or occasionally unavailable. Results are capped at 50 unique entries; the data is historical from public logs and may include expired or revoked certificates, and no API key is sent.",
                ar: "يتطلّب اتصالاً بالإنترنت، وقد تكون crt.sh بطيئة أو غير متاحة أحيانًا. النتائج مقتصرة على 50 إدخالًا فريدًا، والبيانات تاريخية من السجلات العامة وقد تتضمّن شهادات منتهية أو مُلغاة، ولا يُرسَل أي مفتاح."
            )
        ),
        "whois": ToolHelpContent(
            overview: LocalizedText(
                en: "Performs a classic WHOIS query for a domain's registration data: registrar, creation/updated/expiry dates, and name servers. It connects directly to a WHOIS server over TCP on port 43 and shows the raw text plus a parsed summary.",
                ar: "تُنفّذ استعلام WHOIS الكلاسيكي لبيانات تسجيل نطاق: المُسجِّل وتواريخ الإنشاء والتحديث والانتهاء وخوادم الأسماء. تتصل مباشرة بخادم WHOIS عبر TCP على المنفذ 43 وتعرض النص الخام مع ملخّص محلّل."
            ),
            howItWorks: LocalizedText(
                en: "It picks a WHOIS server by TLD (com/net to whois.verisign-grs.com, org to whois.pir.org, sa to whois.nic.net.sa, and others to whois.iana.org), opens a TCP connection to server:43 with an 8-second timeout, sends the domain, and reads the full response; WhoisParser then extracts structured fields.",
                ar: "تختار خادم WHOIS حسب الامتداد (com/net إلى whois.verisign-grs.com، وorg إلى whois.pir.org، وsa إلى whois.nic.net.sa، وغيرها إلى whois.iana.org)، وتفتح اتصال TCP إلى server:43 بمهلة 8 ثوانٍ، وترسل النطاق، وتقرأ كامل الرد؛ ثم يستخرج WhoisParser الحقول المنظّمة."
            ),
            example: LocalizedText(
                en: "Domain « example.com »: server whois.verisign-grs.com is chosen; output includes Registrar RESERVED-Internet Assigned Numbers Authority, creation date 1995-08-14, and name servers like a.iana-servers.net.",
                ar: "النطاق « example.com »: يُختار الخادم whois.verisign-grs.com؛ ويتضمّن الناتج المُسجِّل RESERVED-Internet Assigned Numbers Authority وتاريخ إنشاء 1995-08-14 وخوادم أسماء مثل a.iana-servers.net."
            ),
            notes: LocalizedText(
                en: "Requires outbound TCP on port 43, which some cellular or corporate networks block. Many registries redact owner data for privacy (GDPR); for fresher, more structured data use the RDAP tool.",
                ar: "يتطلّب سماح الشبكة بحركة TCP الخارجة على المنفذ 43، وهو منفذ قد تحجبه بعض الشبكات الخلوية أو المؤسسية. كثير من السجلات تُخفي بيانات المالك لأسباب الخصوصية (GDPR)؛ ولبيانات أحدث وأكثر تنظيمًا استخدم أداة RDAP."
            )
        ),
        "rdap": ToolHelpContent(
            overview: LocalizedText(
                en: "Fetches structured registration data for a domain or IP via RDAP, the modern successor to WHOIS that returns JSON. It uses the rdap.org bootstrap service to route the query to the authoritative registry.",
                ar: "تجلب بيانات التسجيل المنظّمة لنطاق أو عنوان IP عبر بروتوكول RDAP، الخلف الحديث لـ WHOIS الذي يعيد JSON. تستخدم خدمة rdap.org كنقطة إقلاع توجّه الاستعلام إلى السجل المخوّل."
            ),
            howItWorks: LocalizedText(
                en: "It auto-detects the kind (IP if the text has a colon or is only digits and dots, else domain), sends a GET to https://rdap.org/<ip|domain>/<query> on port 443 with the rdap+json Accept header and a 15-second timeout, then parses name, handle, statuses, events, nameservers, and registrar from vCard entities.",
                ar: "تحدّد النوع تلقائيًا (IP إن احتوى النص على نقطتين رأسيتين أو كان أرقامًا ونقاطًا فقط، وإلا نطاق)، وترسل GET إلى https://rdap.org/<ip|domain>/<query> على المنفذ 443 مع ترويسة Accept الخاصة بـ rdap+json ومهلة 15 ثانية، ثم تحلّل الاسم والمعرّف والحالات والأحداث وخوادم الأسماء والمُسجِّل من كيانات vCard."
            ),
            example: LocalizedText(
                en: "Query « example.com »: name example.com, registrar Internet Assigned Numbers Authority, events including registration 1995-08-14 and expiration 2025-08-13, statuses like client delete prohibited. Query « 8.8.8.8 » is treated as an IP and returns Google's block data.",
                ar: "الاستعلام « example.com »: الاسم example.com، والمُسجِّل Internet Assigned Numbers Authority، وأحداث مثل registration 1995-08-14 وexpiration 2025-08-13، وحالات مثل client delete prohibited. أما « 8.8.8.8 » فيُعامَل كعنوان IP ويعيد بيانات كتلة Google."
            ),
            notes: LocalizedText(
                en: "Requires an internet connection and relies on the rdap.org bootstrap; some legacy TLDs may not support RDAP and return 404. As with WHOIS many personal fields are redacted, but being over HTTPS on port 443 it works across restricted networks more reliably than WHOIS on port 43.",
                ar: "يتطلّب اتصالاً بالإنترنت ويعتمد على إقلاع rdap.org؛ وبعض الامتدادات القديمة قد لا تدعم RDAP وترجع 404. مثل WHOIS تُخفى كثير من الحقول الشخصية، لكنه عبر HTTPS على المنفذ 443 أكثر قابلية للعمل عبر الشبكات المقيّدة من WHOIS على المنفذ 43."
            )
        ),
        "email-security": ToolHelpContent(
            overview: LocalizedText(
                en: "Checks a domain's email-authentication records: SPF, DMARC, and DKIM. It reveals whether the domain is protected against spoofing by looking up TXT DNS records using DNS-over-HTTPS.",
                ar: "تفحص سجلات مصادقة البريد لنطاق ما: SPF وDMARC وDKIM. تكشف ما إذا كان النطاق محميًا ضد الانتحال عبر البحث في سجلات DNS من نوع TXT باستخدام DNS-over-HTTPS."
            ),
            howItWorks: LocalizedText(
                en: "It runs three encrypted TXT queries (RFC 8484, POST to https://cloudflare-dns.com/dns-query on port 443): SPF on the domain (v=spf1), DMARC on _dmarc.<domain> (v=dmarc1), and DKIM on <selector>._domainkey.<domain> (p=). Quotes are stripped and the first matching value is returned, case-insensitive.",
                ar: "تنفّذ ثلاثة استعلامات TXT مشفّرة (RFC 8484، POST إلى https://cloudflare-dns.com/dns-query على المنفذ 443): SPF على النطاق (v=spf1)، وDMARC على _dmarc.<domain> (v=dmarc1)، وDKIM على <selector>._domainkey.<domain> (p=). تُزال علامات الاقتباس وتُعاد أول قيمة مطابِقة دون حساسية لحالة الأحرف."
            ),
            example: LocalizedText(
                en: "Domain « google.com », selector google: SPF present with v=spf1 include:_spf.google.com ~all; DMARC present with v=DMARC1; p=reject; DKIM present with a public key beginning v=DKIM1; k=rsa; p=…",
                ar: "النطاق « google.com » والمُحدِّد google: SPF present بقيمة v=spf1 include:_spf.google.com ~all؛ وDMARC present بقيمة v=DMARC1; p=reject؛ وDKIM present بمفتاح عام يبدأ بـ v=DKIM1; k=rsa; p=…"
            ),
            notes: LocalizedText(
                en: "The DKIM check uses a single selector; if the domain uses a different one it shows absent even though DKIM exists, so try common selectors like google, s1, or selector1. It relies on the fixed Cloudflare resolver, requires internet, and only checks record presence, not validity.",
                ar: "يعتمد فحص DKIM على مُحدِّد واحد؛ فإن استخدم النطاق مُحدِّدًا مختلفًا ظهر absent رغم وجود DKIM فعليًا، لذا جرّب مُحدِّدات شائعة مثل google أو s1 أو selector1. يعتمد على مُحلِّل Cloudflare الثابت ويتطلّب إنترنت، ويتحقّق من وجود السجل فقط لا من صحّته."
            )
        ),
        "email-validator": ToolHelpContent(
            overview: LocalizedText(
                en: "Checks the syntax of an address, then queries the MX records of its domain to estimate whether it is deliverable. The syntax check is purely local, layered with a real DNS query for MX.",
                ar: "يتحقق من صحة صيغة العنوان ثم يستعلم عن سجلات MX لنطاقه ليقدّر قابليته للتسليم. التحقق النصي محلي بحت، ويُضاف إليه استعلام DNS حقيقي لسجلات MX."
            ),
            howItWorks: LocalizedText(
                en: "First a pragmatic RFC 5322-lite check requires exactly one @ separating a non-empty local part from a domain that contains a dot, with only allowed characters and no spaces. If valid, an MX query is sent via UDPDNSResolver to 1.1.1.1 on port 53; the address is deliverable when the syntax is valid and at least one MX record returns.",
                ar: "أولًا فحص مبسّط لـ RFC 5322 يشترط وجود @ واحدة تفصل جزءًا محليًا غير فارغ عن نطاق يحتوي نقطة، بأحرف مسموحة فقط وبلا مسافات. إن صحّت الصيغة يُرسَل استعلام MX عبر UDPDNSResolver إلى 1.1.1.1 على المنفذ 53؛ ويُعدّ العنوان قابلًا للتسليم إذا صحّت الصيغة وعاد سجل MX واحد على الأقل."
            ),
            example: LocalizedText(
                en: "Input « user@gmail.com »: syntax valid, and the query to 1.1.1.1 returns MX records such as gmail-smtp-in.l.google.com, showing a deliverable badge. In contrast « user@b » is rejected for lacking a TLD.",
                ar: "المدخل « user@gmail.com »: الصيغة صحيحة، والاستعلام إلى 1.1.1.1 يعيد سجلات MX مثل gmail-smtp-in.l.google.com، فتظهر بشارة deliverable. أما « user@b » فترفض لغياب TLD."
            ),
            notes: LocalizedText(
                en: "An MX record does not guarantee the specific mailbox exists; it only indicates the domain can receive mail. The query uses the 1.1.1.1 (Cloudflare) resolver over UDP, and some networks block port 53.",
                ar: "وجود سجل MX لا يضمن أن صندوق المستخدم نفسه موجود؛ إنه مؤشّر على قابلية النطاق لاستقبال البريد فقط. يعتمد الاستعلام على مُحلِّل 1.1.1.1 (Cloudflare) عبر UDP، وقد تحجب بعض الشبكات المنفذ 53."
            )
        ),
        "rbl-check": ToolHelpContent(
            overview: LocalizedText(
                en: "Tests whether an IPv4 address is listed on public DNS-based blocklists (DNSBL/RBL) used for anti-spam. It queries several well-known zones and shows which ones list the address, using real DNS queries.",
                ar: "تتحقق مما إذا كان عنوان IPv4 مُدرجًا في قوائم حظر عامة قائمة على DNS (DNSBL/RBL) لمكافحة البريد المزعج. تستعلم عن عدة مناطق معروفة وتبيّن أيها يُدرج العنوان عبر استعلامات DNS حقيقية."
            ),
            howItWorks: LocalizedText(
                en: "For each zone it reverses the IPv4 octets and appends the zone (e.g. 4.3.2.1.zen.spamhaus.org), then sends an A query via UDPDNSResolver to 1.1.1.1 on port 53. Any returned A record means listed, otherwise clean. Zones include zen.spamhaus.org, bl.spamcop.net, b.barracudacentral.org, dnsbl.sorbs.net, cbl.abuseat.org, and dnsbl-1.uceprotect.net.",
                ar: "لكل منطقة تعكس ثمانيات عنوان IPv4 وتلحق اسم المنطقة (مثل 4.3.2.1.zen.spamhaus.org)، ثم ترسل استعلام A عبر UDPDNSResolver إلى 1.1.1.1 على المنفذ 53. أي سجل A يعني مُدرج، وإلا فنظيف. تشمل المناطق zen.spamhaus.org وbl.spamcop.net وb.barracudacentral.org وdnsbl.sorbs.net وcbl.abuseat.org وdnsbl-1.uceprotect.net."
            ),
            example: LocalizedText(
                en: "Input « 8.8.8.8 »: the tool builds queries such as 8.8.8.8.zen.spamhaus.org; no A record returns, so the badge shows clean and all zones are clean.",
                ar: "المدخل « 8.8.8.8 »: تبني الأداة استعلامات مثل 8.8.8.8.zen.spamhaus.org، ولا يعود أي سجل A، فتظهر البشارة clean وكل المناطق نظيفة."
            ),
            notes: LocalizedText(
                en: "IPv4 only. Some public zones rate-limit queries from shared resolvers like 1.1.1.1 and may return inconclusive results, and listing or delisting changes over time.",
                ar: "تدعم IPv4 فقط. بعض المناطق العامة تفرض حدودًا على الاستعلامات من مُحلِّلات مشتركة كـ 1.1.1.1 وقد تعيد نتائج غير حاسمة، والإدراج والرفع يتغيّران بمرور الوقت."
            )
        ),
        "pwned-check": ToolHelpContent(
            overview: LocalizedText(
                en: "Checks whether a password has appeared in known data breaches using Have I Been Pwned. It uses the k-anonymity model: neither the password nor its full hash is ever sent, only the first 5 hex characters of the SHA-1 hash.",
                ar: "تتحقّق مما إذا كانت كلمة مرور قد ظهرت في تسريبات معروفة عبر خدمة Have I Been Pwned. تستخدم نموذج k-anonymity: لا تُرسَل كلمة المرور ولا بصمتها الكاملة أبدًا، بل أول 5 خانات ست عشرية من بصمة SHA-1 فقط."
            ),
            howItWorks: LocalizedText(
                en: "The SHA-1 hash is computed locally via CryptoKit and split into a 5-char prefix and a suffix. Only the prefix is sent in a GET to https://api.pwnedpasswords.com/range/<prefix> on port 443 with the Add-Padding header; the server returns all suffixes sharing that prefix with counts, and the suffix is matched locally so it never leaves the device.",
                ar: "تُحسَب بصمة SHA-1 محليًا عبر CryptoKit وتُقسَم إلى بادئة من 5 خانات ولاحقة. تُرسَل البادئة فقط في طلب GET إلى https://api.pwnedpasswords.com/range/<prefix> على المنفذ 443 مع ترويسة Add-Padding؛ يعيد الخادم كل اللواحق المشتركة في البادئة مع عدّاداتها، وتُطابَق اللاحقة محليًا فلا تغادر الجهاز."
            ),
            example: LocalizedText(
                en: "Enter the common password « password »: its SHA-1 begins with 5BAA6; only that prefix is sent, the suffix is matched locally, and it shows pwned an enormous number of times. A strong random password would instead show safe.",
                ar: "أدخِل كلمة المرور الشائعة « password »: تبدأ بصمتها SHA-1 بـ 5BAA6؛ تُرسَل هذه البادئة فقط وتُطابَق اللاحقة محليًا، فتظهر مُخترَقة بعدد هائل من المرات. أما كلمة مرور عشوائية قوية فستظهر safe."
            ),
            notes: LocalizedText(
                en: "Thanks to k-anonymity the HIBP server sees only the first 5 hex chars and cannot infer the password. Requires internet; prefer not to enter a real in-use password except to verify it, and safe means only that it has not appeared in breaches, not that it is inherently strong.",
                ar: "بفضل k-anonymity يرى خادم HIBP أول 5 خانات فقط ولا يمكنه استنتاج كلمة المرور. يتطلّب إنترنت، ويُفضّل ألا تُدخِل كلمة مرور حقيقية قيد الاستخدام إلا للتحقّق، و« آمنة » تعني فقط عدم ظهورها في التسريبات لا أنها قوية بحد ذاتها."
            )
        ),
        "ntp": ToolHelpContent(
            overview: LocalizedText(
                en: "Asks a network time server for the current time and compares it to your device's clock to compute the offset. It uses the SNTP protocol (RFC 4330) over UDP, building the request and parsing the reply locally.",
                ar: "تسأل خادم وقت شبكي عن الوقت الحالي وتقارنه بساعة جهازك لحساب الفارق (offset). تستخدم بروتوكول SNTP (RFC 4330) فوق UDP، وتبني الطلب وتحلّل الرد محليًا."
            ),
            howItWorks: LocalizedText(
                en: "It builds a 48-byte SNTP request (first byte 0x1B, client mode) and sends it via UDPExchange to the server on port 123 with a 5-second timeout. From the reply it reads the transmit timestamp (bytes 40 to 43), subtracts the fixed 2208988800 to convert to the Unix epoch, and computes the offset as server time minus now.",
                ar: "تبني رسالة طلب SNTP طولها 48 بايت (البايت الأول 0x1B بوضع العميل) وترسلها عبر UDPExchange إلى الخادم على المنفذ 123 بمهلة 5 ثوانٍ. من الرد تقرأ طابع الإرسال الزمني (البايتات 40 إلى 43)، وتطرح الإزاحة الثابتة 2208988800 للتحويل إلى حقبة يونكس، وتحسب الفارق كوقت الخادم ناقص الآن."
            ),
            example: LocalizedText(
                en: "Input « time.apple.com »: server time 2026-07-12 09:15:03 UTC, offset +0.021 s, meaning your device clock is about 21 milliseconds behind.",
                ar: "المدخل « time.apple.com »: وقت الخادم 2026-07-12 09:15:03 UTC، والفارق +0.021 s، أي أن ساعة جهازك متأخرة بنحو 21 مللي ثانية."
            ),
            notes: LocalizedText(
                en: "SNTP here reads only the transmit timestamp and does not compensate for round-trip time, so the offset includes network delay and may not reflect true skew at millisecond precision. Some networks block port 123 (UDP).",
                ar: "يقرأ SNTP هنا طابع الإرسال فقط ولا يعوّض عن زمن الرحلة، لذا يشمل الفارق تأخير الشبكة وقد لا يعكس الانحراف الحقيقي بدقة المللي ثانية. بعض الشبكات تحجب المنفذ 123 (UDP)."
            )
        ),
        "guide": ToolHelpContent(
            overview: LocalizedText(
                en: "An in-app help screen that explains how to use NetToolbox's tools and set up permissions. Its content is static and bundled with the app, with zero network access, orienting you to the home screen, search, key tools, and the Local Network permission.",
                ar: "شاشة مساعدة مدمجة تشرح كيفية استخدام أدوات NetToolbox وإعداد الأذونات. محتواها ثابت ومُجمّع مع التطبيق دون أي اتصال بالشبكة، وتعرّفك بالصفحة الرئيسية والبحث والأدوات الأساسية وإذن الشبكة المحلية."
            ),
            howItWorks: LocalizedText(
                en: "The tool is a fixed list of sections rendered as text only, with no protocol, port, or external service. Bundled sections include intro, home, tools and search, Wi-Fi info, permissions, Local Network, professional tools, limits, and self-tests; each is simply localized text from the app bundle.",
                ar: "الأداة قائمة ثابتة من الأقسام تُعرَض نصيًا فقط، دون أي بروتوكول أو منفذ أو خدمة خارجية. تشمل الأقسام المقدمة والصفحة الرئيسية والأدوات والبحث ومعلومات الواي-فاي والأذونات والشبكة المحلية والأدوات الاحترافية والقيود والاختبارات الذاتية؛ وكل قسم مجرد نص مُترجَم من ملفات التطبيق."
            ),
            example: LocalizedText(
                en: "Open the Guide: the Local Network card explains that the LAN Scanner and SSDP need the iOS Local Network permission, enabled via iOS Settings then NetToolbox then Local Network if nothing is found.",
                ar: "افتح الدليل: تظهر بطاقة الشبكة المحلية تشرح أن ماسح LAN وSSDP يحتاجان إذن الشبكة المحلية من iOS، ويُفعَّل من إعدادات iOS ثم NetToolbox ثم الشبكة المحلية إذا لم يُعثَر على أجهزة."
            ),
            notes: LocalizedText(
                en: "No internet connection and no permission requested. Content is static and does not update dynamically; for per-tool detail see each tool's own page, and there are no privacy concerns since nothing is transmitted.",
                ar: "لا يتصل بالإنترنت ولا يطلب أي إذن. المحتوى ثابت ولا يتحدّث ديناميكيًا؛ ولتفاصيل كل أداة راجع صفحتها، ولا خصوصية مطروحة لأن لا بيانات تُرسَل."
            )
        ),
        "history": ToolHelpContent(
            overview: LocalizedText(
                en: "Shows recent runs from across the tools (such as Subnet, DNS, WHOIS, IP Info) in one place. Everything is local on the device, and you can export, import, or clear the log.",
                ar: "يعرض آخر العمليات التي شغّلتها عبر مختلف الأدوات (مثل الشبكة الفرعية وDNS وWHOIS ومعلومات IP) في مكان واحد. كل شيء محلي على الجهاز، ويمكنك تصدير السجل أو استيراده أو مسحه."
            ),
            howItWorks: LocalizedText(
                en: "History is stored locally in HistoryStore with no network access. Supported tools log each run with its toolID, input, a summary, and a date; the screen lists them via ToolRegistry. Export uses exportJSONString() and import reads a .json or plain-text file.",
                ar: "يُخزَّن السجل محليًا في HistoryStore بلا أي اتصال بالشبكة. تسجّل الأدوات المدعومة كل تشغيل بمعرّف الأداة والمُدخل والملخّص والتاريخ، وتعرضها الشاشة عبر ToolRegistry. يتم التصدير عبر exportJSONString() والاستيراد من ملف .json أو نص عادي."
            ),
            example: LocalizedText(
                en: "After using IP Info on 8.8.8.8 and the Subnet Calculator, History shows two rows: IP Info — 8.8.8.8 — Mountain View, United States and Subnet — 192.168.1.0/24. Tap Export to share the file as JSON.",
                ar: "بعد استخدام معلومات IP على 8.8.8.8 وحاسبة الشبكة الفرعية، يعرض السجل صفّين: IP Info — 8.8.8.8 — Mountain View, United States وSubnet — 192.168.1.0/24. اضغط تصدير لمشاركة الملف بصيغة JSON."
            ),
            notes: LocalizedText(
                en: "All data stays on-device and is never uploaded. Not every tool logs to History, only those that call history.log; import merges or replaces per the store's internal logic, and no permission or internet is required.",
                ar: "كل البيانات على الجهاز فقط ولا تُرفع لأي خادم. ليست كل الأدوات تسجّل، فقط تلك التي تستدعي history.log؛ والاستيراد يدمج أو يستبدل حسب منطق المخزن الداخلي، ولا يتطلب أي إذن أو إنترنت."
            )
        ),
        "backup": ToolHelpContent(
            overview: LocalizedText(
                en: "Exports your on-device saved data to a shareable JSON file and restores it later, with an option to encrypt the file with a password. A backup includes saved hosts, SSH profiles, cameras, and speed-test history.",
                ar: "تصدّر بياناتك المحفوظة على الجهاز إلى ملف JSON قابل للمشاركة وتعيد استيرادها لاحقًا، مع خيار تشفير الملف بكلمة مرور. تشمل النسخة المضيفين المحفوظين وملفات SSH والكاميرات وسجل اختبارات السرعة."
            ),
            howItWorks: LocalizedText(
                en: "The app gathers data into an AppBackup struct (version 1) and encodes it with a pretty-printed, sorted-keys JSONEncoder. Unencrypted it saves NetToolbox-backup.json; with encryption on it runs BackupCrypto.encrypt and saves NetToolbox-backup.ntbackup. On import encrypted files are auto-detected, and restore replaces the current data entirely, all local with no server.",
                ar: "يجمع التطبيق البيانات في بنية AppBackup (إصدار 1) ويُرمّزها بـ JSONEncoder منسّق ومُرتّب المفاتيح. بلا تشفير يُحفَظ NetToolbox-backup.json، ومع التشفير يمرّ عبر BackupCrypto.encrypt ويُحفَظ NetToolbox-backup.ntbackup. عند الاستيراد تُكتشَف الملفات المشفّرة تلقائيًا، والاستعادة تستبدل البيانات الحالية بالكامل، وكل ذلك محلي بلا خادم."
            ),
            example: LocalizedText(
                en: "Turn on Encrypt, enter a password, then Export: a NetToolbox-backup.ntbackup file is created to share. Later Import that file: you are prompted for the password, and after decryption the current data is replaced and a restore-done message appears.",
                ar: "فعّل التشفير وأدخِل كلمة مرور ثم صدّر: يُنشأ ملف NetToolbox-backup.ntbackup للمشاركة. لاحقًا استورد الملف نفسه: يُطلَب إدخال كلمة المرور، وبعد فكّها تُستبدَل البيانات الحالية وتظهر رسالة تمام الاستعادة."
            ),
            notes: LocalizedText(
                en: "Restore replaces all your current data with no merge, so be careful. A forgotten encrypted-backup password cannot be recovered; files are saved in the app's Documents directory, sensitive secrets stay protected, and no internet is required.",
                ar: "الاستعادة تستبدل كل بياناتك الحالية بلا دمج، فانتبه. لا يمكن استعادة نسخة مشفّرة نُسيت كلمة مرورها؛ وتُحفَظ الملفات في مجلد مستندات التطبيق، وتبقى الأسرار الحسّاسة محميّة، ولا يتطلب إنترنت."
            )
        ),
        "self-test": ToolHelpContent(
            overview: LocalizedText(
                en: "Runs the built-in engine test suite (EngineTestSuite) directly on the device, verifying the correctness of all of the app's computational and protocol engines against known test vectors. All tests are local and make no network calls.",
                ar: "تشغّل مجموعة اختبارات المحرّك المدمجة (EngineTestSuite) على الجهاز مباشرةً، وتتحقق من صحة كل المحرّكات الحسابية والبروتوكولية ضد متجهات اختبار معروفة. كل الاختبارات محلية ولا تتصل بالشبكة."
            ),
            howItWorks: LocalizedText(
                en: "Pressing Run calls EngineTestSuite.runAll(), which executes dozens of independent cases returning nil on pass or a message on failure. Cases cover many engines: subnet math, DNS encode/decode, SNMPv3 USM key derivation, NTP, hash functions, JWT, TLS grading, WHOIS parsing, WireGuard key derivation, and more.",
                ar: "يستدعي الضغط على تشغيل الدالة EngineTestSuite.runAll() التي تنفّذ عشرات الحالات المستقلة، كل حالة تُعيد nil عند النجاح أو رسالة عند الفشل. تغطّي الحالات محرّكات عديدة: حساب الشبكات الفرعية، وترميز وفك DNS، واشتقاق مفاتيح SNMPv3 USM، وNTP، ودوال التجزئة، وJWT، وتصنيف TLS، وتحليل WHOIS، واشتقاق مفاتيح WireGuard، وغيرها."
            ),
            example: LocalizedText(
                en: "Pressing Run shows 62 / 62 and an All passed badge. If the TLS grade heuristics case failed, it would show a message like modern EC expected A+, got A.",
                ar: "يعرض الضغط على تشغيل النتيجة 62 / 62 وبشارة All passed. لو فشلت حالة تصنيف TLS لظهرت رسالة مثل modern EC expected A+, got A."
            ),
            notes: LocalizedText(
                en: "This is a developer tool for verifying engine logic only; it does not test real network connectivity or the UI. It runs entirely offline with no permissions, and the suite mirrors the test vectors in Tests/NetToolboxKitTests.",
                ar: "هذه أداة للمطوّرين للتحقق من منطق المحرّكات فقط، ولا تختبر الاتصال الشبكي الفعلي أو واجهة المستخدم. تعمل بالكامل دون إنترنت أو أذونات، وتعكس المجموعة متجهات الاختبار في Tests/NetToolboxKitTests."
            )
        ),
    ]
}
