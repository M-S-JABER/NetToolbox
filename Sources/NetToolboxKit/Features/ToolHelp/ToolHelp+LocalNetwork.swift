import Foundation

extension ToolHelp {
    static let localNetworkHelp: [String: ToolHelpContent] = [
        "network-overview": ToolHelpContent(
            overview: LocalizedText(
                en: "A compact dashboard of your device connectivity: connection type (Wi-Fi, cellular, or offline), your public IP with ISP and country, and the local IP of every active interface. It is the natural starting point before using the other scanning tools.",
                ar: "لوحة موجزة عن اتصال جهازك: نوع الاتصال (Wi-Fi أو خلوي أو غير متصل)، والـ IP العام مع مزوّد الخدمة والدولة، وعناوين IP المحلية لكل واجهة نشطة. إنها نقطة البداية قبل استخدام أدوات الفحص الأخرى."
            ),
            howItWorks: LocalizedText(
                en: "Connection status comes from NWPathMonitor (and flags metered links). Local addresses are read on-device via getifaddrs for each non-loopback interface, tagged IPv4 or IPv6. The public IP, ISP, and country are fetched over HTTPS from ipwho.is. It refreshes on open and with pull-to-refresh.",
                ar: "حالة الاتصال تأتي من NWPathMonitor وتكشف الاتصال محدود التكلفة. العناوين المحلية تُقرأ محليًا عبر getifaddrs لكل واجهة غير loopback مع تصنيف IPv4 أو IPv6. الـ IP العام والمزوّد والدولة يُجلبون عبر HTTPS من ipwho.is. يتحدّث عند الفتح وبالسحب للأسفل."
            ),
            example: LocalizedText(
                en: "On home Wi-Fi the connection card reads Wi-Fi, the public IP card shows 188.53.120.44 with ISP Saudi Telecom Company and country Saudi Arabia (SA), and the local card lists en0 · IPv4 · 192.168.8.101 alongside an fe80:: IPv6 row.",
                ar: "على شبكة منزلية عبر Wi-Fi تعرض بطاقة الاتصال Wi-Fi، وبطاقة الـ IP العام 188.53.120.44 مع المزوّد Saudi Telecom Company والدولة Saudi Arabia (SA)، وتُظهر البطاقة المحلية en0 · IPv4 · 192.168.8.101 وصفًّا لعنوان fe80:: من نوع IPv6."
            ),
            notes: LocalizedText(
                en: "Reading your own addresses needs no special permission, but the discovery tools require the iOS Local Network permission (Settings ← NetToolbox ← Local Network) and return empty results without it. The public IP fetch needs internet; an fe80:: address is a normal IPv6 link-local address.",
                ar: "قراءة عناوين جهازك لا تتطلب صلاحية خاصة، لكن أدوات الاكتشاف تتطلب صلاحية الشبكة المحلية في iOS (الإعدادات ← NetToolbox ← الشبكة المحلية) وتُرجع نتائج فارغة بدونها. جلب الـ IP العام يحتاج إنترنتًا؛ وعنوان fe80:: هو IPv6 محلي للرابط وهو طبيعي."
            )
        ),
        "wifi-info": ToolHelpContent(
            overview: LocalizedText(
                en: "Shows what an iOS app can obtain about the current Wi-Fi connection: the device IP on the Wi-Fi interface (en0) and the public IP with ISP. It also honestly lists the metrics iOS hides (SSID, signal, channel) and offers a Shortcuts button that can retrieve some of them.",
                ar: "تعرض ما يمكن لتطبيق iOS الحصول عليه عن اتصال Wi-Fi الحالي: عنوان الجهاز على واجهة Wi-Fi (en0) والـ IP العام مع المزوّد. كما توضح القياسات التي تحجبها iOS (SSID وقوة الإشارة والقناة) وتوفّر زر اختصار Shortcuts يمكنه جلب بعضها."
            ),
            howItWorks: LocalizedText(
                en: "The Wi-Fi interface is named en0; the tool reads addresses via getifaddrs and filters for the en0 IPv4 address, falling back to all IPv4. The public IP comes from ipwho.is over HTTPS. Wireless metrics (SSID, RSSI, channel, band, generation, link speed, gateway, vendor) are blocked for ordinary apps, so they appear locked. Two buttons open the Shortcuts app to run or create a shortcut that can read the network name.",
                ar: "واجهة Wi-Fi تُسمّى en0؛ تقرأ الأداة العناوين عبر getifaddrs وتُرشّح عنوان en0 من نوع IPv4، وإن غاب ترجع لكل عناوين IPv4. الـ IP العام يأتي من ipwho.is عبر HTTPS. القياسات اللاسلكية (SSID وRSSI والقناة والنطاق والجيل وسرعة الوصلة والبوابة والمُصنّع) محجوبة عن التطبيقات العادية فتظهر مقفلة. زرّان يفتحان تطبيق Shortcuts لتشغيل أو إنشاء اختصار يقرأ اسم الشبكة."
            ),
            example: LocalizedText(
                en: "On an office Wi-Fi the first card shows Wi-Fi, device address 10.0.5.23, public IP 85.194.x.x, ISP Mobily, and the limitations card shows eight locked rows. Tapping Run shortcut hands off to Shortcuts and runs the NetToolbox WiFi shortcut if it exists.",
                ar: "على شبكة مكتب تُظهر البطاقة الأولى Wi-Fi، وعنوان الجهاز 10.0.5.23، والـ IP العام 85.194.x.x، والمزوّد Mobily، وتعرض بطاقة القيود ثمانية صفوف مقفلة. الضغط على تشغيل الاختصار ينتقل إلى Shortcuts ويشغّل اختصار NetToolbox WiFi إن وُجد."
            ),
            notes: LocalizedText(
                en: "Reading the en0 address needs no permission, but the app discovery tools require the iOS Local Network permission (Settings ← NetToolbox ← Local Network) and return empty results without it. SSID, signal, channel, and link speed are a system limitation, not a tool defect. The shortcut buttons need the Shortcuts app and the named shortcut installed.",
                ar: "قراءة عنوان en0 لا تتطلب صلاحية، لكن أدوات الاكتشاف في التطبيق تتطلب صلاحية الشبكة المحلية في iOS (الإعدادات ← NetToolbox ← الشبكة المحلية) وتُرجع نتائج فارغة بدونها. حجب SSID وقوة الإشارة والقناة وسرعة الوصلة قيد نظامي لا عيب في الأداة. أزرار الاختصار تحتاج تطبيق Shortcuts والاختصار المسمّى مثبَّتًا."
            )
        ),
        "lan-scanner": ToolHelpContent(
            overview: LocalizedText(
                en: "Finds every device it can on your local network, merged into one list: it sweeps your subnet with ping + TCP probes, browses Bonjour/mDNS for advertised services (SSH, file sharing, AirPlay, printers, Chromecast, HomeKit…), and reverse-DNS-names each address. Each device shows its name, IP, services and round-trip time, and can be saved to Saved Hosts.",
                ar: "يعثر على أكبر عدد ممكن من أجهزة شبكتك المحلية في قائمة واحدة: يمسح شبكتك الفرعية بفحوص ping وTCP، ويتصفّح Bonjour/mDNS للخدمات المُعلَنة (SSH ومشاركة الملفات وAirPlay والطابعات وChromecast وHomeKit…)، ويسمّي كل عنوان بـDNS العكسي. يعرض كل جهاز اسمه وIP وخدماته وزمن الذهاب والإياب، ويمكن حفظه في المضيفين المحفوظين."
            ),
            howItWorks: LocalizedText(
                en: "It expands your interface's subnet and probes each host with an unprivileged ICMP ping raced against a TCP-connect (so hosts that filter ICMP are still found), while NWBrowser looks for Bonjour service types over mDNS. Bonjour hits resolve to an IP, every discovered address is reverse-DNS-named, and the three signals merge into one device list keyed by IP.",
                ar: "يوسّع الشبكة الفرعية لواجهتك ويفحص كل مضيف بـICMP ping غير مميّز متسابقًا مع اتصال TCP (فتُكتشف حتى الأجهزة التي تحجب ICMP)، بينما يبحث NWBrowser عن أنواع خدمات Bonjour عبر mDNS. تُحلّ نتائج Bonjour إلى IP، ويُسمّى كل عنوان مكتشف بـDNS عكسي، وتُدمج الإشارات الثلاث في قائمة أجهزة واحدة مفتاحها IP."
            ),
            example: LocalizedText(
                en: "Tapping Scan on a home network lists, within a few seconds: nas.local at 192.168.8.10 (File sharing, 3 ms), an HP printer at 192.168.8.45 (Printer, 5 ms), raspberrypi at 192.168.8.60 (SSH, 2 ms), plus a few bare IPs that answered ping but advertise nothing. You bookmark the Raspberry Pi to save it.",
                ar: "الضغط على فحص على شبكة منزلية يُظهر خلال ثوانٍ: nas.local على 192.168.8.10 (مشاركة ملفات، 3 مللي)، وطابعة HP على 192.168.8.45 (طابعة، 5 مللي)، وraspberrypi على 192.168.8.60 (SSH، 2 مللي)، إضافةً إلى عناوين IP مجرّدة ردّت على ping دون أن تُعلن شيئًا. تنقر الإشارة المرجعية لحفظ الراسبيري باي."
            ),
            notes: LocalizedText(
                en: "Requires the iOS Local Network permission (Settings ← NetToolbox ← Local Network); without it discovery returns nothing with no visible error. A full /24 sweep takes several seconds. iOS still can't see a device that answers no ping, no probed TCP port, and no Bonjour — that's a platform limit (no ARP/raw sockets), not a bug; a desktop ARP scanner can see more.",
                ar: "يتطلب صلاحية الشبكة المحلية في iOS (الإعدادات ← NetToolbox ← الشبكة المحلية)؛ بدونها لا يعثر على شيء دون خطأ ظاهر. مسح /24 كامل يستغرق عدة ثوانٍ. ومع ذلك لا يستطيع iOS رؤية جهاز لا يردّ على ping ولا على أي منفذ TCP مفحوص ولا على Bonjour — هذا قيد نظام (لا ARP ولا raw sockets) وليس خللًا؛ وفاحص ARP على حاسوب يرى أكثر."
            )
        ),
        "ip-range-scanner": ToolHelpContent(
            overview: LocalizedText(
                en: "Sweeps a CIDR range and identifies the live hosts within it by probing reachability, measuring round-trip time. The field is pre-filled with your device subnet so you can scan immediately. Useful for finding every connected device, even ones that do not advertise via Bonjour.",
                ar: "يمسح نطاق CIDR ويحدّد المضيفين النشطين عبر اختبار الوصول مع قياس زمن الرحلة. الحقل معبّأ مسبقًا بالشبكة الفرعية لجهازك حتى تبدأ فورًا. مفيد لاكتشاف كل الأجهزة المتصلة حتى التي لا تُعلن عبر Bonjour."
            ),
            howItWorks: LocalizedText(
                en: "It expands the CIDR into host addresses via SubnetEngine (max 1024 hosts), then probes each in parallel (up to 24 at once) two ways: an unprivileged ICMP ping (0.9s timeout) that gives a true round-trip when allowed, and a TCP-connect probe that still finds hosts where ICMP is filtered. A host counts as alive if either succeeds.",
                ar: "توسّع الأداة نطاق CIDR إلى قائمة مضيفين عبر SubnetEngine (بحدٍّ أقصى 1024 مضيفًا)، ثم تختبر كلًّا منها بالتوازي (حتى 24 معًا) بطريقتين: ping عبر ICMP غير مميّز (مهلة 0.9 ثانية) يعطي زمن رحلة حقيقيًا عند السماح، واختبار اتصال TCP يجد المضيفين حتى حيث يُحجب ICMP. يُعتبر المضيف حيًّا إذا نجحت أي منهما."
            ),
            example: LocalizedText(
                en: "The field is pre-filled with 192.168.8.0/24. You tap Scan; the counter advances to 254 / 254 and eight live hosts appear, among them 192.168.8.1 at 2 ms (router), 192.168.8.10 at 5 ms (NAS), and 192.168.8.101 at 1 ms (your device). History records 192.168.8.0/24 — 8 up / 254.",
                ar: "الحقل معبّأ بـ 192.168.8.0/24. تضغط فحص؛ يتقدّم العدّاد إلى 254 / 254 وتظهر ثمانية مضيفين نشطين منهم 192.168.8.1 بزمن 2 ms (الراوتر)، و192.168.8.10 بزمن 5 ms (خادم NAS)، و192.168.8.101 بزمن 1 ms (جهازك). يُسجَّل في السجل 192.168.8.0/24 — 8 up / 254."
            ),
            notes: LocalizedText(
                en: "Scanning the local subnet invokes the iOS Local Network permission (Settings ← NetToolbox ← Local Network); without it the tool returns empty results. The max is 1024 hosts, and ranges wider than /22 are rejected. Some devices block both ICMP and TCP-connect and stay hidden; when found via TCP the number reflects connect time, not a ping echo.",
                ar: "مسح الشبكة الفرعية المحلية يستدعي صلاحية الشبكة المحلية في iOS (الإعدادات ← NetToolbox ← الشبكة المحلية)؛ بدونها تُرجع الأداة نتائج فارغة. الحد الأقصى 1024 مضيفًا، والنطاقات الأوسع من /22 تُرفض. بعض الأجهزة تحجب ICMP واتصال TCP معًا فلا تظهر؛ وعند اكتشافها عبر TCP يعكس الرقم زمن الاتصال لا صدى ping."
            )
        ),
        "ssdp": ToolHelpContent(
            overview: LocalizedText(
                en: "Discovers UPnP devices on your local network via SSDP — routers (Internet Gateway Devices), media servers, smart TVs, and speakers. It sends a multicast search query and collects the devices replies with their addresses and description URLs.",
                ar: "يكتشف أجهزة UPnP على شبكتك المحلية عبر بروتوكول SSDP — الراوترات (بوابات الإنترنت IGD) وخوادم الوسائط وأجهزة التلفاز الذكية ومكبّرات الصوت. يرسل استعلام بحث متعدد الإرسال ويجمع ردود الأجهزة مع عناوينها وروابط وصفها."
            ),
            howItWorks: LocalizedText(
                en: "It opens a UDP socket and sends an M-SEARCH message to the SSDP multicast address 239.255.255.250 on port 1900, specifying the chosen search target and a max reply delay, then listens for 4 seconds. Each reply is parsed for LOCATION (the XML description URL), SERVER, ST, and USN, and duplicates are removed by USN.",
                ar: "تفتح مقبس UDP وترسل رسالة M-SEARCH إلى عنوان البث المتعدد لـ SSDP وهو 239.255.255.250 على المنفذ 1900، محدّدةً هدف البحث المختار وأقصى تأخير للرد، ثم تستمع أربع ثوانٍ. كل رد يُحلَّل لاستخراج LOCATION (رابط ملف الوصف XML) وSERVER وST وUSN، وتُزال التكرارات حسب USN."
            ),
            example: LocalizedText(
                en: "You pick IGD (router) and tap Scan. After four seconds one device appears: address 192.168.8.1, server RT-AC68U UPnP/1.1 MiniUPnPd/2.1, location http://192.168.8.1:52869/rootDesc.xml, and search target InternetGatewayDevice:1 — indicating your router supports UPnP port forwarding.",
                ar: "تختار IGD (router) وتضغط فحص. بعد أربع ثوانٍ يظهر جهاز واحد: العنوان 192.168.8.1، والخادم RT-AC68U UPnP/1.1 MiniUPnPd/2.1، والموقع http://192.168.8.1:52869/rootDesc.xml، وهدف البحث InternetGatewayDevice:1 — ما يشير إلى أن راوترك يدعم UPnP لإعادة توجيه المنافذ."
            ),
            notes: LocalizedText(
                en: "Multicast on iOS needs a networking entitlement and touching the local network invokes the Local Network permission (Settings ← NetToolbox ← Local Network); without the right permissions the send fails and the tool returns an empty list with no visible error. Devices without UPnP/SSDP will not appear, and the fixed four-second window may miss slow responders.",
                ar: "البث المتعدد على iOS يحتاج صلاحية شبكة، والوصول للشبكة المحلية يستدعي صلاحية الشبكة المحلية (الإعدادات ← NetToolbox ← الشبكة المحلية)؛ بدون الصلاحيات المناسبة يفشل الإرسال وتُرجع الأداة قائمة فارغة دون خطأ ظاهر. الأجهزة بلا دعم UPnP/SSDP لن تظهر، ونافذة الأربع ثوانٍ قد تفوّت الأجهزة البطيئة."
            )
        ),
        "wake-on-lan": ToolHelpContent(
            overview: LocalizedText(
                en: "Wakes a sleeping or powered-off device that supports Wake-on-LAN by sending a magic packet to its MAC address over the local network. Useful for powering on a desktop PC or NAS without physically reaching it.",
                ar: "توقظ جهازًا نائمًا أو مُطفأ يدعم Wake-on-LAN بإرسال حزمة سحرية إلى عنوان MAC الخاص به عبر الشبكة المحلية. مفيدة لتشغيل حاسوب مكتبي أو خادم NAS دون الوصول الفيزيائي إليه."
            ),
            howItWorks: LocalizedText(
                en: "It builds the standard magic packet (6 bytes of 0xFF then the target MAC repeated 16 times, 102 bytes total) and sends it over a broadcast-enabled UDP socket to the entered broadcast address (default 255.255.255.255) on the entered port (default 9, sometimes 7). The target network card wakes the machine on receipt; the tool only sends and does not wait for a reply.",
                ar: "تبني الحزمة السحرية القياسية (6 بايتات من 0xFF ثم عنوان MAC الهدف مكرّرًا 16 مرة، بمجموع 102 بايت) وترسلها عبر مقبس UDP مُفعَّل عليه البث إلى عنوان البث المُدخل (افتراضيًّا 255.255.255.255) على المنفذ المُدخل (افتراضيًّا 9، وأحيانًا 7). تُوقظ بطاقة شبكة الهدف الجهاز عند الاستقبال؛ والأداة ترسل فقط ولا تنتظر ردًّا."
            ),
            example: LocalizedText(
                en: "To wake a NAS you enter MAC 00:11:32:AA:BB:CC, leave broadcast 255.255.255.255 and port 9, and tap Wake. A sent badge appears, and the server wakes within seconds if WoL is enabled in its settings and network card.",
                ar: "لإيقاظ خادم NAS تُدخل عنوان MAC هو 00:11:32:AA:BB:CC، وتترك البث 255.255.255.255 والمنفذ 9، وتضغط إيقاظ. تظهر شارة تم الإرسال، ويستيقظ الخادم خلال ثوانٍ إن كان WoL مُفعَّلًا في إعداداته وبطاقة شبكته."
            ),
            notes: LocalizedText(
                en: "Sending the broadcast on the local network invokes the iOS Local Network permission (Settings ← NetToolbox ← Local Network); without it the send may fail and results are empty. WoL must be enabled in the target BIOS/UEFI or OS and its network card; the magic packet works within the LAN only. A sent badge means the packet left, not that the target woke — verify with the IP Range Scanner.",
                ar: "إرسال البث على الشبكة المحلية يستدعي صلاحية الشبكة المحلية في iOS (الإعدادات ← NetToolbox ← الشبكة المحلية)؛ بدونها قد يفشل الإرسال وتكون النتائج فارغة. يجب تفعيل WoL في BIOS/UEFI أو نظام الجهاز الهدف وبطاقة شبكته؛ والحزمة تعمل داخل الشبكة المحلية فقط. شارة تم الإرسال تعني أن الحزمة غادرت لا أن الجهاز استيقظ — تحقّق عبر فاحص مدى IP."
            )
        ),
        "saved-hosts": ToolHelpContent(
            overview: LocalizedText(
                en: "A simple address book for storing frequently used hosts (IP addresses, domain names, or MAC addresses) with a name and optional note, so they can be recalled with one tap in the other tools instead of retyping. Data is stored locally and synced via iCloud when available.",
                ar: "دفتر عناوين بسيط لحفظ المضيفين المتكرّرين (عناوين IP أو أسماء نطاقات أو عناوين MAC) باسم وملاحظة اختيارية، فتُستدعى بنقرة في الأدوات الأخرى بدل إعادة كتابتها. تُخزَّن البيانات محليًا وتُزامَن عبر iCloud عند توفّره."
            ),
            howItWorks: LocalizedText(
                en: "This tool does no networking; it is purely a local store. The list is saved as JSON in UserDefaults under the key nettoolbox.hosts.v1. Each host has a UUID, name, address, and note; whitespace is trimmed and a blank name falls back to the address. It reloads when iCloud sync pulls newer values, and saved hosts surface in tools like Wake-on-LAN and Camera through a picker.",
                ar: "هذه الأداة لا تُجري أي اتصال شبكي؛ إنها مخزن محلي فقط. تُحفظ القائمة بصيغة JSON في UserDefaults تحت المفتاح nettoolbox.hosts.v1. كل مضيف يحمل UUID واسمًا وعنوانًا وملاحظة؛ يُقتطع الفراغ، وإن تُرك الاسم فارغًا يُستخدم العنوان. تُعاد القائمة عندما تجلب مزامنة iCloud قيمًا أحدث، وتظهر العناوين في أدوات مثل Wake-on-LAN والكاميرا عبر قائمة اختيار."
            ),
            example: LocalizedText(
                en: "You type name Home NAS, address 192.168.8.10, note Synology - office, and tap Save; the row appears. Later, in the Wake-on-LAN or Camera tool, you can pick 192.168.8.10 straight from the saved-hosts menu.",
                ar: "تكتب الاسم Home NAS، والعنوان 192.168.8.10، والملاحظة Synology - office، وتضغط حفظ؛ فيظهر الصف. لاحقًا في أداة Wake-on-LAN أو الكاميرا يمكنك اختيار 192.168.8.10 مباشرةً من قائمة المضيفين."
            ),
            notes: LocalizedText(
                en: "This tool does no networking, so it needs no Local Network permission. But the tools that consume these addresses (range scanner, camera, Wake-on-LAN) require the iOS Local Network permission when they touch the network (Settings ← NetToolbox ← Local Network) and return empty results without it. Data lives in UserDefaults; deleting a host here is permanent and removed from iCloud on sync.",
                ar: "هذه الأداة لا تتصل بالشبكة، لذا لا تتطلب صلاحية الشبكة المحلية. لكن الأدوات التي تستهلك هذه العناوين (فحص المدى والكاميرا وWake-on-LAN) تتطلب صلاحية الشبكة المحلية في iOS عند مخاطبة الشبكة (الإعدادات ← NetToolbox ← الشبكة المحلية) وتُرجع نتائج فارغة بدونها. تُحفظ البيانات في UserDefaults؛ وحذف مضيف هنا نهائي ويُزال من iCloud عند المزامنة."
            )
        ),
        "camera": ToolHelpContent(
            overview: LocalizedText(
                en: "Displays a live feed from IP cameras on your network over RTSP, with automatic discovery, smart ONVIF setup, still snapshots, clip recording, pan/tilt/zoom control, and a multi-camera grid. Camera profiles are stored locally with passwords kept in the Keychain.",
                ar: "يعرض بثًّا مباشرًا من كاميرات IP على شبكتك عبر بروتوكول RTSP، مع اكتشاف تلقائي، وإعداد ذكي عبر ONVIF، والتقاط صور ثابتة، وتسجيل مقاطع، والتحكّم بالحركة PTZ، وعرض شبكي لعدة كاميرات. تُحفظ ملفات الكاميرات محليًّا مع تخزين كلمات المرور في Keychain."
            ),
            howItWorks: LocalizedText(
                en: "Because iOS AVFoundation has no RTSP, the app uses a hand-written RTSP client over Network framework (DESCRIBE, SETUP, PLAY with Basic/Digest auth), demuxes H.264/H.265 packets, and renders CMSampleBuffer frames. Auto-setup uses ONVIF SOAP (default port 80) to fetch device info, stream URI, and snapshot URI. Discovery sweeps the /24 subnet with a TCP-connect probe on port 554, and PTZ uses ONVIF ContinuousMove.",
                ar: "لأن AVFoundation في iOS لا يدعم RTSP يستخدم التطبيق عميل RTSP مكتوبًا يدويًّا فوق إطار Network (DESCRIBE وSETUP وPLAY مع مصادقة Basic/Digest)، ويفكّك حزم H.264/H.265، ويعرض إطارات CMSampleBuffer. الإعداد التلقائي يستخدم ONVIF عبر SOAP (المنفذ 80 افتراضيًّا) لجلب معلومات الجهاز ورابط البث ورابط اللقطة. الاكتشاف يمسح الشبكة الفرعية /24 باختبار اتصال TCP على المنفذ 554، والتحكّم PTZ يستخدم أمر ONVIF ContinuousMove."
            ),
            example: LocalizedText(
                en: "You tap Scan; the tool finds 192.168.8.50 with port 554 open. You select it, enter username admin and the password, and tap ONVIF to fetch manufacturer Hikvision, model DS-2CD2043, a 2560×1440 stream with path /Streaming/Channels/101. You save and tap play, and the live feed appears with a Live badge.",
                ar: "تضغط فحص؛ فتكتشف الأداة 192.168.8.50 بمنفذ 554 مفتوح. تختاره وتُدخل اسم المستخدم admin وكلمة المرور، وتضغط ONVIF فتُجلب المُصنّع Hikvision والطراز DS-2CD2043 وملف بث بدقّة 2560×1440 ومسار /Streaming/Channels/101. تحفظ وتضغط تشغيل فيظهر البث المباشر بشارة Live."
            ),
            notes: LocalizedText(
                en: "This tool requires the iOS Local Network permission to connect to and discover cameras (Settings ← NetToolbox ← Local Network); without it discovery is empty and the stream may fail. Discovery relies on a TCP sweep of port 554, so cameras on a non-standard RTSP port must be added manually. Auto-setup depends on ONVIF support; camera passwords live in the Keychain and are removed when the camera is deleted.",
                ar: "تتطلب هذه الأداة صلاحية الشبكة المحلية في iOS للاتصال بالكاميرات ولاكتشافها (الإعدادات ← NetToolbox ← الشبكة المحلية)؛ بدونها يكون الاكتشاف فارغًا وقد يفشل البث. الاكتشاف يعتمد على مسح المنفذ 554 عبر TCP، فالكاميرات على منفذ RTSP غير قياسي تُضاف يدويًّا. الإعداد التلقائي يعتمد على دعم ONVIF؛ وكلمات المرور تُخزَّن في Keychain وتُحذف عند حذف الكاميرا."
            )
        ),
        "wifi-qr": ToolHelpContent(
            overview: LocalizedText(
                en: "Generates a Wi-Fi QR code so any phone can scan it with the camera and join the network automatically without typing the password. The generator runs entirely on-device — no data is sent to any server.",
                ar: "يولّد رمز QR لشبكة Wi-Fi فيستطيع أي هاتف مسحه بالكاميرا للاتصال بالشبكة تلقائيًّا دون كتابة كلمة المرور. المولّد يعمل بالكامل محليًّا على الجهاز — لا يُرسل أي بيانات إلى أي خادم."
            ),
            howItWorks: LocalizedText(
                en: "This is a purely local generator with no networking. It builds a string following the standard WIFI: scheme that iOS and Android cameras understand (T for security, S for SSID, P for password, H for hidden), escaping special characters in the SSID and password and omitting the password field for open networks. The string is encoded to a QR image via CoreImage; the payload builder is pure and unit-tested.",
                ar: "هذا مولّد محلي بحت بلا اتصال شبكي. يبني نصًّا وفق مخطط WIFI: القياسي الذي تفهمه كاميرات iOS وAndroid (T للأمان، وS لاسم الشبكة، وP لكلمة المرور، وH للمخفية)، ويُهرّب الرموز الخاصة في الاسم وكلمة المرور، ويحذف حقل كلمة المرور للشبكات المفتوحة. يُرمَّز النص إلى صورة QR عبر CoreImage؛ ودالة بناء النص نقيّة ومغطّاة باختبارات."
            ),
            example: LocalizedText(
                en: "You enter SSID MyHomeWiFi, pick WPA, type password p@ss;word, and leave hidden off. The generator builds WIFI:T:WPA;S:MyHomeWiFi;P:p@ss;word;H:false (with the semicolon escaped) and shows the QR code. Your guest scans it and connects instantly.",
                ar: "تُدخل SSID هو MyHomeWiFi، وتختار WPA، وتكتب كلمة المرور p@ss;word، وتترك المخفية معطّلة. يبني المولّد WIFI:T:WPA;S:MyHomeWiFi;P:p@ss;word;H:false (مع تهريب الفاصلة المنقوطة) ويعرض رمز QR. يمسحه ضيفك فيتصل فورًا."
            ),
            notes: LocalizedText(
                en: "This is a fully local generator with no networking, so it does not require the Local Network permission or any network access. (The app's other network tools do; enable it via Settings ← NetToolbox ← Local Network.) It cannot read your current network or password — iOS blocks that, so enter details manually. QR-to-connect works on iOS 11+ and most modern Android phones; older devices may not.",
                ar: "هذا مولّد محلي بالكامل بلا اتصال شبكي، لذا لا يتطلب صلاحية الشبكة المحلية ولا أي أذونات شبكية. (أدوات التطبيق الأخرى التي تخاطب الشبكة تتطلبها؛ لتفعيلها: الإعدادات ← NetToolbox ← الشبكة المحلية.) لا يقرأ شبكتك الحالية ولا كلمة مرورها لأن iOS يحجب ذلك، فأدخِل البيانات يدويًّا. المسح للاتصال متوفّر في iOS 11+ وأغلب هواتف Android الحديثة؛ والأقدم قد لا تدعمه."
            )
        ),
        "wireguard-qr": ToolHelpContent(
            overview: LocalizedText(
                en: "Builds a WireGuard tunnel (VPN) configuration and turns it into a QR code that the official WireGuard app can import by scanning. It generates key pairs locally using Curve25519 via CryptoKit — the same curve WireGuard uses — so no external tooling is needed. The configuration never leaves the device unless you share it.",
                ar: "يبني ملف إعداد نفق WireGuard (VPN) ويحوّله إلى رمز QR يستطيع تطبيق WireGuard الرسمي استيراده بمجرد مسحه. يولّد أزواج المفاتيح محليًّا عبر منحنى Curve25519 من CryptoKit — نفس المنحنى الذي يستخدمه WireGuard — فلا حاجة لأدوات خارجية. الإعداد لا يغادر الجهاز إلا إذا شاركته أنت."
            ),
            howItWorks: LocalizedText(
                en: "This is a purely local generator with no networking. It assembles a .conf string from two sections: [Interface] (private key, address, DNS) and [Peer] (server public key, preshared key, endpoint, allowed IPs, keepalive), omitting empty fields. Keys are generated via Curve25519.KeyAgreement encoded as Base64, and the public key is derived automatically from a pasted private key. The full config is encoded to a QR code via CoreImage.",
                ar: "هذا مولّد محلي بحت بلا اتصال شبكي. يُجمِّع نص .conf من قسمين: [Interface] (المفتاح الخاص والعنوان وDNS) و[Peer] (مفتاح الخادم العام والمفتاح المشترك مسبقًا ونقطة النهاية والعناوين المسموحة والإبقاء الدوري)، محذوفًا الحقول الفارغة. تُولَّد المفاتيح عبر Curve25519.KeyAgreement وتُرمَّز Base64، ويُشتقّ المفتاح العام تلقائيًّا من المفتاح الخاص المُلصق. يُرمَّز الإعداد كاملًا إلى رمز QR عبر CoreImage."
            ),
            example: LocalizedText(
                en: "You tap Generate; a new private key appears with its derived public key (copy it to register on the server). You paste the peer public key, enter endpoint vpn.example.com:51820, and leave the rest at defaults (Address 10.0.0.2/32, DNS 1.1.1.1, AllowedIPs 0.0.0.0/0, Keepalive 25). The QR and config text appear, and you add the tunnel in WireGuard by scanning.",
                ar: "تضغط توليد؛ فيظهر مفتاح خاص جديد مع مفتاحه العام المشتقّ (انسخه لتسجّله على الخادم). تلصق مفتاح النظير العام، وتُدخل نقطة النهاية vpn.example.com:51820، وتترك البقيّة على الافتراضي (العنوان 10.0.0.2/32، وDNS هو 1.1.1.1، والعناوين المسموحة 0.0.0.0/0، والإبقاء 25). يظهر رمز QR ونص الإعداد، وتضيف النفق في WireGuard بالمسح."
            ),
            notes: LocalizedText(
                en: "This is a fully local generator with no networking, so it does not require the Local Network permission or any network access. (The app's other network tools do; enable it via Settings ← NetToolbox ← Local Network.) It only builds the client config — the actual connection happens in the WireGuard app after import. The private key is sensitive and embedded in the QR; the peer public key and endpoint must match the server.",
                ar: "هذا مولّد محلي بالكامل بلا اتصال شبكي، لذا لا يتطلب صلاحية الشبكة المحلية ولا أي أذونات شبكية. (أدوات التطبيق الأخرى التي تخاطب الشبكة تتطلبها؛ لتفعيلها: الإعدادات ← NetToolbox ← الشبكة المحلية.) يُنشئ إعداد العميل فقط — والاتصال الفعلي يتم في تطبيق WireGuard بعد الاستيراد. المفتاح الخاص حسّاس ومضمَّن في الرمز؛ ويجب أن يتطابق مفتاح النظير العام ونقطة النهاية مع الخادم."
            )
        )
    ]
}
