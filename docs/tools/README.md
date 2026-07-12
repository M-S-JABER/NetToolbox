# NetToolbox — دليل الأدوات المُفصّل · Per-Tool Documentation

<div dir="rtl">

هذا الدليل يحتوي على **صفحة مستقلة لكل أداة** من أدوات NetToolbox الـ84، بشرح وافٍ **بالعربية والإنجليزية**: نظرة عامة، كيف تعمل الأداة داخلياً، المدخلات، المخرجات، مثال تشغيل حقيقي، والقيود.

- التطبيق يعمل **محلياً بالكامل على الجهاز** وبدون أي مكتبات خارجية. الأدوات الوحيدة التي تتصل بالإنترنت هي التي تجلب بيانات عامة (العنوان العام، اختبار السرعة، WHOIS/RDAP، فحص التسريبات، التوجيه العالمي) وكل واحدة منها تذكر خدمتها بوضوح.
- أدوات **الشبكة المحلية** (الماسح، نطاق العناوين، SSDP/UPnP، الكاميرات) تحتاج صلاحية «الشبكة المحلية» في iOS: الإعدادات ← NetToolbox ← الشبكة المحلية.
- أدوات **ICMP** (Ping، Traceroute، ماسح النطاق) تتحوّل تلقائياً إلى مصافحة TCP عندما تحجب الشبكة ICMP.

</div>

This directory holds a **standalone page for every one of NetToolbox's 84 tools**, each fully bilingual (Arabic + English): overview, how it works internally, inputs, outputs, a worked example, and limitations. The tool docs are grouped by category below.

---

## 🧮 الحاسبات · Calculators

| الأداة · Tool | الوصف · Description |
|---|---|
| [Subnet Calculator · حاسبة الشبكات الفرعية](subnet-calculator.md) | حساب الشبكة والبث ونطاق المضيفين — IPv4/IPv6 |
| [Subnet Membership · انتماء الشبكة](subnet-membership.md) | هل عنوان IP داخل كتلة CIDR |
| [VLSM Planner · مخطط VLSM](vlsm.md) | تقسيم شبكة إلى شبكات فرعية بأحجام متغيرة |
| [MAC / OUI Lookup · بحث MAC/OUI](mac-lookup.md) | الشركة المصنّعة من عنوان MAC |
| [Common Ports · المنافذ الشائعة](port-reference.md) | مرجع منافذ TCP/UDP المعروفة |
| [Base Converter · محوّل الأنظمة العددية](number-converter.md) | تحويل بين ثنائي/عشري/ست عشري |
| [Text Converter · محوّل النصوص](text-converter.md) | Base64/Hex/URL وغيرها |
| [Password Generator · مولّد كلمات المرور](password-generator.md) | كلمات مرور قوية عشوائية |
| [QR Generator · مولّد رموز QR](qr-generator.md) | إنشاء رموز QR من نص |
| [Hash & JWT · التجزئة و JWT](crypto-tools.md) | تجزئة وفك ترميز JWT |
| [Hash Identifier · مُعرّف التجزئة](hash-id.md) | تخمين نوع التجزئة |
| [EUI-64 / SLAAC](eui64.md) | اشتقاق عنوان IPv6 من MAC |
| [CIDR Aggregator · مُجمّع CIDR](cidr-aggregate.md) | دمج كتل CIDR المتجاورة |
| [Timestamp Converter · محوّل الطابع الزمني](timestamp.md) | Unix epoch ↔ تاريخ بشري |
| [Generators · المولّدات](generators.md) | UUID / MAC عشوائية |
| [JSON Formatter · مُنسّق JSON](json-formatter.md) | تنسيق والتحقق من JSON |
| [Regex Tester · مُختبِر التعابير النمطية](regex.md) | اختبار regex ومطابقاته |
| [URL Parser · مُحلّل الروابط](url-parser.md) | تفكيك مكوّنات الرابط |
| [Data Calculator · حاسبة البيانات](data-calc.md) | أحجام البيانات وزمن النقل |

## 🩺 التشخيص · Diagnostics

| الأداة · Tool | الوصف · Description |
|---|---|
| [Guide · الدليل](guide.md) | دليل الاستخدام داخل التطبيق |
| [Public IP & ISP · العنوان العام والمزوّد](public-ip.md) | عنوانك العام ومزوّد الخدمة |
| [IP Info Lookup · معلومات عنوان IP](ip-info.md) | الموقع الجغرافي و ASN لأي IP |
| [Host → IP · اسم المضيف إلى IP](host-to-ip.md) | تحليل اسم النطاق إلى عنوان |
| [Speed Test · اختبار السرعة](speed-test.md) | تحميل/رفع/زمن استجابة/تذبذب |
| [HTTP Request · طلب HTTP](http-request.md) | إرسال طلبات HTTP مخصّصة |
| [History · السجل](history.md) | سجل عمليات الأدوات |
| [Backup & Restore · النسخ والاستعادة](backup.md) | تصدير/استيراد بيانات التطبيق |
| [Ping (TCP) · بينغ](ping.md) | فحص الوصول وزمن الاستجابة |
| [World Ping · بينغ عالمي](world-ping.md) | بينغ من مواقع حول العالم |
| [Traceroute · تتبّع المسار](traceroute.md) | مسار الحزم حتى الوجهة |
| [MTR Path Analysis · تحليل المسار MTR](mtr.md) | فقد/زمن لكل قفزة |
| [Port Scanner · ماسح المنافذ](port-scanner.md) | فحص المنافذ المفتوحة |
| [DNS Lookup · استعلام DNS](dns-lookup.md) | استعلام سجلات DNS |
| [DNS over HTTPS · DNS عبر HTTPS](doh.md) | استعلام DoH مشفّر |
| [DNS Compare · مقارنة DNS](dns-compare.md) | مقارنة عدة مُحلّلات |
| [DNS Stability · استقرار DNS](dns-reliability.md) | موثوقية زمن استجابة DNS |
| [DNS Health · صحة DNS](dns-health.md) | فحوص صحّة النطاق |
| [Email Security · أمان البريد](email-security.md) | SPF / DKIM / DMARC |
| [Pwned Password · كلمة مرور مسرّبة](pwned-check.md) | فحص تسريب كلمة المرور |
| [Cert Transparency · شفافية الشهادات](cert-transparency.md) | سجلّات شهادات النطاق |
| [WHOIS](whois.md) | بيانات تسجيل النطاق |
| [RDAP Lookup · استعلام RDAP](rdap.md) | بديل WHOIS المُهيكل |
| [Banner Grab · التقاط اللافتة](banner-grab.md) | لافتة الخدمة على المنفذ |
| [Service Fingerprint · بصمة الخدمة](fingerprint.md) | تخمين الخدمة من الاستجابة |
| [HTTP Timing · توقيت HTTP](http-timing.md) | تفصيل مراحل طلب HTTP |
| [Uptime Check · فحص التوفّر](uptime.md) | فحص توفّر عدة روابط |
| [Cert Expiry Monitor · مراقبة انتهاء الشهادة](cert-expiry.md) | تاريخ انتهاء شهادة TLS |
| [nslookup](nslookup.md) | تحليل أمامي/عكسي عبر النظام |
| [SSL/TLS Checker · فاحص SSL/TLS](ssl-checker.md) | فحص الشهادة وبروتوكولات TLS |
| [HTTP Headers · ترويسات HTTP](http-headers.md) | عرض ترويسات الاستجابة |
| [Email Validator · مُدقّق البريد](email-validator.md) | التحقق من صيغة البريد |
| [Blacklist Check · فحص القوائم السوداء](rbl-check.md) | فحص RBL/DNSBL |
| [NTP Time · وقت NTP](ntp.md) | مزامنة الوقت عبر SNTP |
| [Engine Self-Tests · الاختبارات الذاتية](self-test.md) | تشغيل اختبارات المحرّكات |

## 🖧 الشبكة المحلية · Local Network

| الأداة · Tool | الوصف · Description |
|---|---|
| [Network Overview · نظرة عامة على الشبكة](network-overview.md) | حالة الاتصال والعناوين |
| [Wi-Fi Info · معلومات الواي فاي](wifi-info.md) | تفاصيل شبكة الواي فاي |
| [Saved Hosts · المضيفون المحفوظون](saved-hosts.md) | إدارة المضيفين المحفوظين |
| [LAN Scanner · ماسح الشبكة المحلية](lan-scanner.md) | اكتشاف الأجهزة على الشبكة |
| [SSDP / UPnP Discovery · اكتشاف SSDP/UPnP](ssdp.md) | اكتشاف أجهزة UPnP |
| [IP Range Scanner · ماسح نطاق العناوين](ip-range-scanner.md) | فحص نطاق عناوين IP |
| [Wake-on-LAN · الإيقاظ عبر الشبكة](wake-on-lan.md) | إيقاظ جهاز عبر حزمة سحرية |
| [IP Cameras · كاميرات IP](camera.md) | بث كاميرات RTSP/ONVIF |
| [Wi-Fi QR Code · رمز QR للواي فاي](wifi-qr.md) | مشاركة الواي فاي عبر QR |
| [WireGuard QR · رمز QR لـ WireGuard](wireguard-qr.md) | إعداد WireGuard عبر QR |

## 🛠️ احترافي · Professional

| الأداة · Tool | الوصف · Description |
|---|---|
| [SSH](ssh.md) | صدفة SSH-2 أصلية |
| [SFTP](sftp.md) | نقل ملفات عبر SSH |
| [Telnet](telnet.md) | طرفية Telnet |
| [FTP](ftp.md) | عميل FTP بسيط |
| [WebSocket](websocket.md) | مُختبِر WebSocket |
| [MQTT Client · عميل MQTT](mqtt.md) | نشر/اشتراك MQTT |
| [Redis](redis.md) | عميل Redis (RESP) |
| [Modbus TCP](modbus.md) | قراءة سجلات Modbus |
| [SMTP Probe · فحص SMTP](smtp.md) | فحص خادم البريد |
| [Memcached](memcached.md) | عميل Memcached |
| [CoAP Client · عميل CoAP](coap.md) | طلبات CoAP |
| [TFTP Client · عميل TFTP](tftp.md) | نقل ملفات TFTP |
| [Syslog Receiver · مستقبِل Syslog](syslog.md) | استقبال رسائل Syslog |
| [SNMP Trap Receiver · مستقبِل SNMP Trap](snmp-trap.md) | استقبال مصائد SNMP |
| [MikroTik API · واجهة ميكروتيك](mikrotik-api.md) | واجهة RouterOS API |
| [SNMP GET](snmp.md) | استعلام SNMP |
| [iperf3 Speed Test · اختبار iperf3](iperf3.md) | قياس الإنتاجية مع خادم iperf3 |

## 🌐 التوجيه العالمي · BGP

| الأداة · Tool | الوصف · Description |
|---|---|
| [ASN Info · معلومات ASN](bgp-asn.md) | بيانات نظام مستقل عبر RIPEstat |
| [IP → BGP](bgp-ip.md) | بادئة/ASN لعنوان عبر RIPEstat |
| [RPKI Validator · مُدقّق RPKI](rpki.md) | حالة RPKI للبادئة/ASN |

---

<div dir="rtl">

**ملاحظة:** للاطلاع على ملخّص موجز لكل الأدوات في صفحة واحدة، راجع [`../TOOLS.md`](../TOOLS.md).

</div>

> For a single-page concise summary of all tools, see [`../TOOLS.md`](../TOOLS.md).
