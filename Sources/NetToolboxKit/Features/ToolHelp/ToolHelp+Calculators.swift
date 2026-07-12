import Foundation

extension ToolHelp {
    static let calculatorsHelp: [String: ToolHelpContent] = [
        "subnet-calculator": ToolHelpContent(
            overview: LocalizedText(
                en: "A full subnet calculator for an IPv4 or IPv6 address. Enter the address and a mask (prefix length or dotted mask) to get the network, broadcast, first/last host, host counts, address class, and scope.",
                ar: "حاسبة شبكات فرعية شاملة لعنوان IPv4 أو IPv6. أدخل العنوان مع القناع (طول البادئة أو قناع منقّط) لتحصل على الشبكة والبث وأول وآخر مضيف وعدد المضيفين وفئة العنوان ونطاقه."
            ),
            howItWorks: LocalizedText(
                en: "All math runs through a pure SubnetEngine, so it works 100% on-device with no network. It handles special cases like /32 (single host) and /31 (point-to-point). IPv6 mode is auto-detected from a colon in the address.",
                ar: "كل الحسابات تجري عبر محرّك SubnetEngine الرياضي الصرف، فيعمل محلياً بالكامل بدون اتصال بالإنترنت. يعالج حالات خاصة مثل /32 (مضيف واحد) و/31 (نقطة-إلى-نقطة). يُكتشف وضع IPv6 تلقائياً عند وجود نقطتين رأسيتين في العنوان."
            ),
            example: LocalizedText(
                en: "Input 192.168.1.10 with 24 gives network 192.168.1.0/24, broadcast 192.168.1.255, hosts 192.168.1.1 to 192.168.1.254 (254 usable), class C, scope Private.",
                ar: "إدخال 192.168.1.10 مع 24 يعطي الشبكة 192.168.1.0/24 والبث 192.168.1.255 والمضيفين من 192.168.1.1 إلى 192.168.1.254 (254 صالحاً) والفئة C والنطاق خاص."
            ),
            notes: LocalizedText(
                en: "No data leaves the device. IPv4-embedded IPv6 notation is not supported, very large IPv6 ranges are shown as a power, and non-contiguous dotted masks are rejected.",
                ar: "لا تُرسل أي بيانات خارج الجهاز. لا يدعم IPv6 المضمّن بترميز IPv4، وتُعرض مدايات IPv6 الكبيرة كأسٍّ، ويُرفض القناع المنقّط غير المتصل."
            )
        ),
        "subnet-membership": ToolHelpContent(
            overview: LocalizedText(
                en: "Answers one question: does a given IP fall inside a specific CIDR subnet or outside it? It also shows the subnet details (network, first/last host, broadcast) to confirm the range visually.",
                ar: "تُجيب على سؤال واحد: هل عنوان IP معيّن يقع داخل شبكة CIDR محددة أم خارجها؟ كما تعرض تفاصيل الشبكة (الشبكة وأول وآخر مضيف والبث) لتأكيد النطاق بصرياً."
            ),
            howItWorks: LocalizedText(
                en: "Pure math on top of SubnetEngine, so it runs 100% on-device with no network. It derives the mask from the prefix and checks whether the masked IP equals the masked network. A CIDR with no slash is assumed to be /24.",
                ar: "حساب رياضي صرف فوق محرّك SubnetEngine، فيعمل محلياً بالكامل بدون اتصال بالإنترنت. يشتق القناع من طول البادئة ويتحقق من تطابق العنوان المُقنّع مع الشبكة المُقنّعة. الـ CIDR بلا شرطة يُفترض /24."
            ),
            example: LocalizedText(
                en: "IP 192.168.1.50 in CIDR 192.168.1.0/24 is inside; the same CIDR with IP 10.0.0.5 is outside.",
                ar: "العنوان 192.168.1.50 ضمن الشبكة 192.168.1.0/24 يقع داخلها؛ ونفس الشبكة مع العنوان 10.0.0.5 يقع خارجها."
            ),
            notes: LocalizedText(
                en: "IPv4 only, no network access whatsoever. An invalid address or CIDR produces an error instead of a result.",
                ar: "خاص بـ IPv4 فقط، ولا اتصال بالشبكة إطلاقاً. العنوان أو الـ CIDR غير الصالح يُنتج رسالة خطأ بدل نتيجة."
            )
        ),
        "vlsm": ToolHelpContent(
            overview: LocalizedText(
                en: "Splits one base network into several differently-sized subnets (Variable-Length Subnet Masking). Enter a base CIDR and named host-count requests, and it packs the subnets tightly (largest first) with minimal waste.",
                ar: "أداة تقسيم شبكة أساسية إلى عدة شبكات فرعية بأحجام مختلفة (VLSM). أدخل شبكة أساسية بصيغة CIDR وطلبات باسم وعدد مضيفين، فتوزّع الشبكات بإحكام (الأكبر أولاً) بأقل هدر."
            ),
            howItWorks: LocalizedText(
                en: "Pure math in VLSMEngine, running 100% on-device with no network. For each request it finds the smallest fitting prefix, sorts largest-first, aligns each block to its boundary, and allocates the range using 64-bit math to avoid overflow.",
                ar: "حساب رياضي صرف في محرّك VLSMEngine، يعمل محلياً بالكامل بدون اتصال بالإنترنت. لكل طلب يحسب أصغر بادئة تكفي، ويرتّب تنازلياً، ويحاذي كل بلوك لحدوده ثم يخصّص المدى بحساب 64-بت لتفادي الفيض."
            ),
            example: LocalizedText(
                en: "Base 192.168.1.0/24 with Sales=50 and IT=20 gives Sales 192.168.1.0/26 (hosts .1 to .62) and IT 192.168.1.64/27 (hosts .65 to .94).",
                ar: "الأساس 192.168.1.0/24 مع Sales=50 وIT=20 يعطي Sales في 192.168.1.0/26 (المضيفون .1 إلى .62) وIT في 192.168.1.64/27 (المضيفون .65 إلى .94)."
            ),
            notes: LocalizedText(
                en: "IPv4 only, no internet access. Requests with zero or negative hosts are ignored, and if the combined sizes exceed the base capacity allocation fails with an error.",
                ar: "IPv4 فقط، بلا اتصال بالإنترنت. الطلبات ذات المضيفين صفر أو أقل تُتجاهل، وإن تجاوز مجموع الأحجام سعة الشبكة الأساسية يفشل التخصيص برسالة خطأ."
            )
        ),
        "cidr-aggregate": ToolHelpContent(
            overview: LocalizedText(
                en: "Merges a list of IPv4 addresses or CIDR blocks into the minimal set of CIDR blocks covering exactly the same address space. Useful for simplifying ACLs and routing tables. Runs 100% on-device with no network.",
                ar: "تدمج قائمة عناوين أو كتل IPv4 في أصغر مجموعة كتل CIDR تغطّي المجال نفسه بالضبط. مفيدة لتبسيط قوائم الوصول وجداول التوجيه. تعمل محلياً بالكامل بدون اتصال بالإنترنت."
            ),
            howItWorks: LocalizedText(
                en: "Input is split on newlines, commas, spaces, or tabs; each line becomes a range using 64-bit math. Adjacent or overlapping ranges are merged, then each is converted to the fewest CIDR blocks. A bare IP is treated as /32.",
                ar: "يُقسَّم المدخل على الأسطر أو الفواصل أو المسافات أو علامات الجدولة؛ كل سطر يصبح مجالاً بحساب 64-بت. تُدمَج المدايات المتلاصقة أو المتداخلة، ثم يُحوَّل كلٌّ إلى أقل عدد من كتل CIDR. العنوان المجرد يُعامَل كـ /32."
            ),
            example: LocalizedText(
                en: "Input 192.168.0.0/25 and 192.168.0.128/25 merges into 192.168.0.0/24; input 10.0.0.0/24 and 10.0.1.0/24 yields 10.0.0.0/23.",
                ar: "إدخال 192.168.0.0/25 و192.168.0.128/25 يُدمَج إلى 192.168.0.0/24؛ وإدخال 10.0.0.0/24 و10.0.1.0/24 يُنتج 10.0.0.0/23."
            ),
            notes: LocalizedText(
                en: "IPv4 only; IPv6 is not supported. Lines that fail to parse are skipped, no network access at all, and the result covers exactly the same range without widening.",
                ar: "IPv4 فقط؛ لا يدعم IPv6. الأسطر التي لا تُحلَّل تُتجاهَل، ولا اتصال بالشبكة إطلاقاً، والنتيجة تغطّي المجال نفسه بالضبط دون توسيع."
            )
        ),
        "eui64": ToolHelpContent(
            overview: LocalizedText(
                en: "Builds a modified EUI-64 interface identifier from a MAC address, then composes the resulting SLAAC IPv6 address under a prefix you supply. Runs 100% on-device with no network.",
                ar: "تبني مُعرِّف الواجهة بصيغة modified EUI-64 من عنوان MAC، ثم تُركّب عنوان IPv6 الناتج عبر SLAAC تحت بادئة تحدّدها. تعمل محلياً بالكامل بدون اتصال بالإنترنت."
            ),
            howItWorks: LocalizedText(
                en: "It keeps the 12 hex digits of the MAC, flips the universal/local bit of the top byte, inserts FF:FE into the middle, then combines the interface ID with the first four groups of your prefix and compresses to canonical IPv6.",
                ar: "تحتفظ بخانات MAC الست عشرية الاثنتي عشرة، وتقلب بِت universal/local في أعلى بايت، وتُدرج FF:FE في المنتصف، ثم تدمج مُعرِّف الواجهة مع أول أربع مجموعات من البادئة وتضغط الناتج بصيغة IPv6 المختصرة."
            ),
            example: LocalizedText(
                en: "For 00:1A:2B:3C:4D:5E with prefix fe80::/64 the interface ID is 021a:2bff:fe3c:4d5e and the address is fe80::21a:2bff:fe3c:4d5e.",
                ar: "لعنوان 00:1A:2B:3C:4D:5E وبادئة fe80::/64 يكون مُعرِّف الواجهة 021a:2bff:fe3c:4d5e والعنوان الناتج fe80::21a:2bff:fe3c:4d5e."
            ),
            notes: LocalizedText(
                en: "The MAC must be exactly 12 hex digits; no data is sent to any server. Only the first four groups of the prefix (a /64) are used. Flipping the U/L bit follows the modified EUI-64 standard.",
                ar: "يجب أن يكون MAC اثنتي عشرة خانة ست عشرية بالضبط؛ ولا تُرسَل أي بيانات لأي خادم. تُستخدم أول أربع مجموعات من البادئة فقط (شبكة /64). قلب بِت U/L يتّبع معيار modified EUI-64."
            )
        ),
        "mac-lookup": ToolHelpContent(
            overview: LocalizedText(
                en: "Parses a 48-bit MAC address in any common format, normalizes it, and identifies the manufacturer from the OUI (first three bytes). It also reveals the multicast and locally-administered bits that mark randomized private MACs.",
                ar: "تحلّل عنوان MAC (48-بت) بأي صيغة شائعة وتُطبّعه وتحدّد الشركة المصنّعة من مفتاح OUI (أول ثلاث بايتات). كما تكشف بِتَّي multicast وlocally-administered اللذين يميّزان عناوين MAC العشوائية الخاصة."
            ),
            howItWorks: LocalizedText(
                en: "Parsing and vendor lookup run 100% on-device with no network, using a bundled abridged OUI database. It accepts any separators, verifies 12 hex digits, looks up the OUI, and reads the two flag bits from the first byte.",
                ar: "التحليل والبحث عن الشركة يجريان محلياً بالكامل بدون اتصال بالإنترنت عبر قاعدة OUI مدمجة مختصرة. تقبل أي فواصل، وتتحقق من 12 خانة ست عشرية، وتبحث عن OUI، وتقرأ بِتَّي الرايات من أول بايت."
            ),
            example: LocalizedText(
                en: "Input f0:18:98:12:34:56 gives normalized F0:18:98:12:34:56, Cisco f018.9812.3456, OUI F01898, vendor Apple, Inc. (if in the DB), Multicast No, Locally administered No.",
                ar: "إدخال f0:18:98:12:34:56 يعطي المطبّع F0:18:98:12:34:56 وصيغة Cisco f018.9812.3456 وOUI F01898 والشركة Apple, Inc. (إن وُجدت في القاعدة) وMulticast لا وLocally administered لا."
            ),
            notes: LocalizedText(
                en: "The vendor database is abridged, so some addresses normalize without a vendor name. Randomized phone MACs show the locally-administered flag with no vendor. The address is never sent to any server.",
                ar: "قاعدة الشركات مختصرة، لذا قد تُطبَّع بعض العناوين دون اسم شركة. العناوين العشوائية في الهواتف تظهر بعلامة locally-administered بلا مُصنّع. لا يُرسل العنوان لأي خادم إطلاقاً."
            )
        ),
        "port-reference": ToolHelpContent(
            overview: LocalizedText(
                en: "A quick, searchable reference for common TCP and UDP ports, showing the port number, protocol, service name, and a short description. Useful while configuring firewalls and reviewing security rules.",
                ar: "مرجع سريع قابل للبحث للمنافذ الشائعة في TCP وUDP، يعرض رقم المنفذ والبروتوكول واسم الخدمة ووصفاً موجزاً. مفيد أثناء إعداد جدران الحماية ومراجعة قواعد الأمان."
            ),
            howItWorks: LocalizedText(
                en: "The data is a static bundled table of about 79 well-known ports, filtered 100% on-device with no network. Search matches the port number start, service name, or description, and the protocol filter limits to TCP, UDP, or all.",
                ar: "البيانات جدول ثابت مدمج من نحو 79 منفذاً معروفاً، تُصفّى محلياً بالكامل بدون اتصال بالإنترنت. البحث يطابق بداية رقم المنفذ أو اسم الخدمة أو الوصف، وفلتر البروتوكول يقصر النتائج على TCP أو UDP أو الكل."
            ),
            example: LocalizedText(
                en: "Search 443 shows HTTPS on TCP and UDP; search ssh shows port 22 on TCP (Secure Shell, remote login, SFTP, tunneling).",
                ar: "بحث 443 يعرض HTTPS على TCP وUDP؛ وبحث ssh يعرض المنفذ 22 على TCP (Secure Shell للدخول عن بُعد وSFTP والأنفاق)."
            ),
            notes: LocalizedText(
                en: "The list is curated to common ports, not the full IANA registry. It is purely a reference with no port scanning or network access; updating it requires an app update.",
                ar: "القائمة منتقاة لأشهر المنافذ وليست سجل IANA الكامل. أداة مرجعية بحتة بلا فحص منافذ أو اتصال بالشبكة؛ وتحديثها يتطلب تحديث التطبيق."
            )
        ),
        "number-converter": ToolHelpContent(
            overview: LocalizedText(
                en: "Converts one number between binary, octal, decimal, and hexadecimal. It auto-detects the input base from a prefix and instantly shows the value in all four bases as you type.",
                ar: "تحوّل رقماً واحداً بين الثنائي والثماني والعشري والست عشري. تكتشف نظام الإدخال تلقائياً من البادئة وتعرض القيمة في الأنظمة الأربعة فوراً أثناء الكتابة."
            ),
            howItWorks: LocalizedText(
                en: "A pure conversion up to 64 bits running 100% on-device with no network. The base is detected from a prefix (0x hex, 0b binary, 0o octal, otherwise decimal), underscores are ignored, and binary output is grouped in nibbles.",
                ar: "تحويل صرف حتى 64 بت يعمل محلياً بالكامل بدون اتصال بالإنترنت. يُكتشف النظام من البادئة (0x ست عشري، 0b ثنائي، 0o ثماني، وإلا عشري)، وتُتجاهَل الشرطة السفلية، ويُجمَّع الثنائي في نيبلات."
            ),
            example: LocalizedText(
                en: "Input 0xFF gives HEX FF, DEC 255, OCT 377, BIN 1111 1111; input 0b1010 gives HEX A, DEC 10, OCT 12.",
                ar: "إدخال 0xFF يعطي HEX FF وDEC 255 وOCT 377 وBIN 1111 1111؛ وإدخال 0b1010 يعطي HEX A وDEC 10 وOCT 12."
            ),
            notes: LocalizedText(
                en: "Maximum value is 64-bit; anything larger shows an overflow error. Positive integers only, no fractions or negative sign. No internet access, computed on-device.",
                ar: "القيمة القصوى 64 بت؛ ما يتجاوزها يُظهر خطأ تجاوز. أرقام صحيحة موجبة فقط بلا كسور أو إشارة سالبة. لا اتصال بالإنترنت، والحساب على الجهاز."
            )
        ),
        "text-converter": ToolHelpContent(
            overview: LocalizedText(
                en: "Encodes and decodes text via three common schemes: Base64, Hex, and URL percent-encoding. Pick an operation, type the text, and the output appears instantly with a copy button.",
                ar: "ترميز وفكّ ترميز النصوص عبر ثلاث صيغ شائعة: Base64 وHex وURL (percent-encoding). اختر العملية واكتب النص فيظهر الناتج فوراً مع زر نسخ."
            ),
            howItWorks: LocalizedText(
                en: "A pure transform running 100% on-device with no network. All text is treated as UTF-8; Hex decoding ignores spaces, colons, and a leading 0x, and URL encoding percent-encodes everything non-alphanumeric.",
                ar: "تحويل صرف يعمل محلياً بالكامل بدون اتصال بالإنترنت. كل النصوص تُعامَل بترميز UTF-8؛ وفكّ Hex يتجاهل المسافات والنقطتين والبادئة 0x، وترميز URL يُرمّز كل ما ليس أبجدياً رقمياً."
            ),
            example: LocalizedText(
                en: "Base64 encode of Hello is SGVsbG8=; hex encode of Hi is 4869; URL encode of a b&c is a%20b%26c.",
                ar: "ترميز Base64 لـ Hello هو SGVsbG8=؛ وترميز Hex لـ Hi هو 4869؛ وترميز URL لـ a b&c هو a%20b%26c."
            ),
            notes: LocalizedText(
                en: "URL encode is more conservative than standard component encoding (spaces become %20). Decoding failures show an error, and inputs and outputs stay on-device with no internet access.",
                ar: "ترميز URL أكثر تحفظاً من ترميز المكوّنات القياسي (المسافة تصبح %20). فشل الفكّ يُظهر خطأ، والمدخلات والمخرجات تبقى على الجهاز بلا اتصال بالإنترنت."
            )
        ),
        "timestamp": ToolHelpContent(
            overview: LocalizedText(
                en: "A two-way converter between a Unix timestamp (seconds or milliseconds since 1970) and a human-readable date. It shows the time in UTC, local, and ISO 8601 forms. Runs 100% on-device with no network.",
                ar: "محوّل ثنائي الاتجاه بين طابع Unix الزمني (ثوانٍ أو ميلي ثانية منذ 1970) والتاريخ المقروء. يعرض الوقت بصيغ UTC والمحلي وISO 8601. يعمل محلياً بالكامل بدون اتصال بالإنترنت."
            ),
            howItWorks: LocalizedText(
                en: "The text is parsed to a number; values above one trillion are treated as milliseconds, otherwise seconds. The reverse direction uses a date picker to produce the timestamp in seconds and milliseconds. Everything runs locally.",
                ar: "يُحوَّل النص إلى رقم؛ القيم فوق تريليون تُعامَل كميلي ثانية وإلا فهي ثوانٍ. الاتجاه المعاكس يستخدم منتقي تاريخ لإنتاج الطابع بالثواني والميلي ثانية. كل شيء يجري محلياً."
            ),
            example: LocalizedText(
                en: "Input 1700000000 gives UTC 2023-11-14 22:13:20 UTC and ISO 2023-11-14T22:13:20Z; 1700000000000 is detected as milliseconds and yields the same date.",
                ar: "إدخال 1700000000 يعطي UTC 2023-11-14 22:13:20 UTC وISO 2023-11-14T22:13:20Z؛ و1700000000000 يُكتشَف كميلي ثانية ويعطي التاريخ نفسه."
            ),
            notes: LocalizedText(
                en: "The seconds/milliseconds threshold is one trillion, so very large values are always milliseconds. The Now button writes seconds only, the local format follows the device locale, and there is no network access.",
                ar: "عتبة الثواني/الميلي ثانية هي تريليون، فالقيم الكبيرة جداً تُعامَل كميلي ثانية دائماً. زر Now يكتب الثواني فقط، والصيغة المحلية تتبع لغة الجهاز، ولا اتصال بالشبكة."
            )
        ),
        "data-calc": ToolHelpContent(
            overview: LocalizedText(
                en: "Converts a data size between decimal and binary units and estimates the time to transfer it at a given speed. It also shows the size in bytes and megabits. Runs 100% on-device with no network.",
                ar: "تحوّل حجم بيانات بين الوحدات العشرية والثنائية وتُقدّر زمن نقله عند سرعة معيّنة. كما تعرض الحجم بالبايت والميغابِت. تعمل محلياً بالكامل بدون اتصال بالإنترنت."
            ),
            howItWorks: LocalizedText(
                en: "Size is converted to bytes (decimal units base 1000, binary units base 1024) and speed to bits per second, then transfer time is size-bits divided by speed. Zero speed gives a dash and huge values may display infinity.",
                ar: "يُحوَّل الحجم إلى بايتات (الوحدات العشرية بأساس 1000 والثنائية بأساس 1024) والسرعة إلى بِت/ثانية، ثم زمن النقل هو بِتات الحجم مقسومة على السرعة. السرعة الصفر تعطي شرطة والقيم الضخمة قد تُعرض لانهاية."
            ),
            example: LocalizedText(
                en: "Size 1 GB at 100 Mbps is 1,000,000,000 bytes and 8000 megabits, and transfer time is 80 seconds, shown as 1m 20s.",
                ar: "حجم 1 GB بسرعة 100 Mbps هو 1,000,000,000 بايت و8000 ميغابِت، وزمن النقل 80 ثانية، يُعرَض 1m 20s."
            ),
            notes: LocalizedText(
                en: "Decimal units use base 1000 and binary units base 1024, so mind the difference. The time is an ideal estimate assuming full speed with no overhead, and there is no network access at all.",
                ar: "الوحدات العشرية بأساس 1000 والثنائية بأساس 1024، فانتبه للفرق. الزمن تقدير مثالي يفترض استغلال السرعة كاملة دون overhead، ولا اتصال بالشبكة إطلاقاً."
            )
        ),
        "url-parser": ToolHelpContent(
            overview: LocalizedText(
                en: "Breaks a URL into its components: scheme, user, password, host, port, path, fragment, and query parameters. Runs 100% on-device with no network and never opens or contacts the URL.",
                ar: "تُفكّك رابط URL إلى مكوّناته: البروتوكول والمستخدم وكلمة المرور والمضيف والمنفذ والمسار والجزء ومعاملات الاستعلام. تعمل محلياً بالكامل بدون اتصال بالإنترنت ولا تفتح الرابط ولا تتصل به."
            ),
            howItWorks: LocalizedText(
                en: "The text is parsed by Foundation URLComponents, valid only if it has at least a scheme or host. Rows are built from the non-empty components in order, and each query item gets its own row. Parsing is fully local.",
                ar: "يُحلَّل النص عبر URLComponents من Foundation، ويُعتبر صالحاً فقط إذا كان له scheme أو host على الأقل. تُبنى الصفوف من المكوّنات غير الفارغة بالترتيب، ولكل معامل استعلام صفٌّ مستقل. التحليل محلي بالكامل."
            ),
            example: LocalizedText(
                en: "Input https://user:pass@example.com:8443/api/v1?q=cats&page=2#top yields Scheme https, Host example.com, Port 8443, Path /api/v1, Fragment top, and query rows q=cats and page=2.",
                ar: "إدخال https://user:pass@example.com:8443/api/v1?q=cats&page=2#top يُنتج Scheme https وHost example.com وPort 8443 وPath /api/v1 وFragment top وصفَّي استعلام q=cats وpage=2."
            ),
            notes: LocalizedText(
                en: "It follows URLComponents rules, so malformed or unencoded URLs may fail to parse. It reveals a password present in the URL (a privacy note when pasting). No network access at all.",
                ar: "تتبع قواعد URLComponents، فالروابط المشوّهة أو غير المُرمَّزة قد تفشل في التحليل. تُظهر كلمة المرور إن وُجدت في الرابط (تحذير خصوصية عند اللصق). لا اتصال بالشبكة إطلاقاً."
            )
        ),
        "json-formatter": ToolHelpContent(
            overview: LocalizedText(
                en: "Validates a JSON string and re-formats it: pretty-printed with indentation or minified onto one line. Keys are sorted alphabetically in both modes. Runs 100% on-device with no network.",
                ar: "تتحقق من صحة نص JSON وتُعيد تنسيقه: طباعة جميلة بمسافات بادئة أو ضغط في سطر واحد. تُرتّب المفاتيح أبجدياً في الحالتين. تعمل محلياً بالكامل بدون اتصال بالإنترنت."
            ),
            howItWorks: LocalizedText(
                en: "Parsing runs locally through Foundation JSONSerialization with fragments allowed, so single values are accepted too. Sorted keys alphabetize output and slashes are not escaped; any parse error is shown as a message.",
                ar: "يجري التحليل محلياً عبر JSONSerialization من Foundation مع قبول القيم المفردة أيضاً. المفاتيح المرتّبة تُرتّب الإخراج أبجدياً ولا تُهرّب الشرطات المائلة؛ وأي خطأ تحليل يُعرَض كرسالة."
            ),
            example: LocalizedText(
                en: "Input with keys b then a, minified, yields the object with a first then b (alphabetical order).",
                ar: "إدخال بمفاتيح b ثم a، مع الضغط، يُنتج الكائن بترتيب a ثم b (أبجدياً)."
            ),
            notes: LocalizedText(
                en: "Re-formatting always sorts keys, so the original order is not preserved. Single-value fragments are accepted and numbers may be re-rendered in canonical form. No network access at all.",
                ar: "إعادة التنسيق ترتّب المفاتيح دائماً، فلا يُحافَظ على ترتيبها الأصلي. القيم المفردة مقبولة وقد يُعاد تمثيل الأرقام بصيغة قياسية. لا اتصال بالشبكة إطلاقاً."
            )
        ),
        "regex": ToolHelpContent(
            overview: LocalizedText(
                en: "Tests a regular expression against a string and shows every match along with the capture groups in each match. Supports a case-insensitive mode. Runs 100% on-device with no network.",
                ar: "تختبر تعبيراً نمطياً على نص وتُظهر كل المطابقات مع المجموعات الملتقطة في كل مطابقة. تدعم وضع تجاهل حالة الأحرف. تعمل محلياً بالكامل بدون اتصال بالإنترنت."
            ),
            howItWorks: LocalizedText(
                en: "An NSRegularExpression is built from the pattern (an invalid pattern shows an error) and matched over the full text via Foundation's ICU engine. Enabling case-insensitive adds that option; all logic is local.",
                ar: "يُبنى NSRegularExpression من النمط (النمط غير الصالح يُظهر خطأ) ويُطابَق على كامل النص عبر محرّك ICU في Foundation. تفعيل تجاهل الحالة يضيف ذلك الخيار؛ وكل المنطق محلي."
            ),
            example: LocalizedText(
                en: "A pattern matching a four-digit year and two-digit month over the text release 2026-07 and update 2025-11 yields two matches, 2026-07 with groups 2026 and 07, and 2025-11 with groups 2025 and 11.",
                ar: "نمط يطابق سنة من أربعة أرقام وشهراً من رقمين على النص release 2026-07 and update 2025-11 يُنتج مطابقتين: 2026-07 بمجموعتين 2026 و07، و2025-11 بمجموعتين 2025 و11."
            ),
            notes: LocalizedText(
                en: "The supported syntax is ICU's NSRegularExpression flavor, which may differ from PCRE. Matching is over UTF-16 ranges, an empty pattern produces no matches, and there is no network access at all.",
                ar: "الصيغة المدعومة هي صيغة ICU الخاصة بـ NSRegularExpression وقد تختلف عن PCRE. المطابقة على مدايات UTF-16، والنمط الفارغ لا يُنتج مطابقات، ولا اتصال بالشبكة إطلاقاً."
            )
        ),
        "password-generator": ToolHelpContent(
            overview: LocalizedText(
                en: "Generates strong, random passwords with customizable length and character sets (lowercase, uppercase, digits, symbols). It shows an entropy estimate in bits with a visual rating and a copy button.",
                ar: "تولّد كلمات مرور قوية عشوائية بطول ومجموعات أحرف قابلة للتخصيص (صغيرة، كبيرة، أرقام، رموز). تعرض تقدير الإنتروبيا بالبتات مع تصنيف مرئي وزر نسخ."
            ),
            howItWorks: LocalizedText(
                en: "Runs 100% on-device with no network, drawing each character from the enabled pool using the system's cryptographically secure RNG. Entropy is estimated as length times log2 of the pool size and rated weak to excellent.",
                ar: "تعمل محلياً بالكامل بدون اتصال بالإنترنت، وتسحب كل خانة من المجموعة المفعّلة عبر مولّد النظام العشوائي الآمن تشفيرياً. تُقدَّر الإنتروبيا بالطول مضروباً في log2 لحجم المجموعة وتُصنَّف من ضعيفة إلى ممتازة."
            ),
            example: LocalizedText(
                en: "Length 16 with all four sets (pool about 85 chars) gives roughly 103 bits of entropy, rated excellent, such as q7$Km2!vP9xL#4nZ.",
                ar: "الطول 16 مع المجموعات الأربع (المجموعة نحو 85 حرفاً) يعطي نحو 103 بت إنتروبيا، تصنيف ممتازة، مثل q7$Km2!vP9xL#4nZ."
            ),
            notes: LocalizedText(
                en: "Uses the secure system RNG; passwords are neither stored nor sent to any server. If all sets are disabled the output is empty, and the entropy estimate assumes uniform randomness.",
                ar: "تستخدم مولّد النظام الآمن؛ كلمات المرور لا تُحفَظ ولا تُرسَل لأي خادم. إذا عُطّلت كل المجموعات يكون الناتج فارغاً، وتقدير الإنتروبيا يفترض عشوائية موحّدة."
            )
        ),
        "generators": ToolHelpContent(
            overview: LocalizedText(
                en: "Generates ready-to-use random identifiers: a UUIDv4, a locally administered MAC address, and a random hex string of a length you choose. Runs 100% on-device with no network.",
                ar: "تولّد مُعرِّفات عشوائية جاهزة: معرّف UUIDv4، وعنوان MAC محلي الإدارة، وسلسلة ست عشرية عشوائية بطول تختاره. تعمل محلياً بالكامل بدون اتصال بالإنترنت."
            ),
            howItWorks: LocalizedText(
                en: "UUID uses Foundation's version-4 generator; MAC forces the first byte to locally administered and unicast; hex prints the chosen number of random bytes (clamped 1 to 256). It keeps the last 20 UUIDs and MACs.",
                ar: "UUID يستخدم مولّد الإصدار الرابع من Foundation؛ وMAC يجعل البايت الأول محلي الإدارة وأحادي البث؛ وHex يطبع عدد البايتات المختار (محصوراً بين 1 و256). تحتفظ بآخر 20 UUID وMAC."
            ),
            example: LocalizedText(
                en: "A UUID might be 9b2e1c7a-4f3d-4a1b-8c2e-1d5f6a7b8c9d, a MAC A2:3F:1B:9C:44:D0 (first byte always locally administered), and hex length 16 yields 32 characters.",
                ar: "قد يعطي UUID مثل 9b2e1c7a-4f3d-4a1b-8c2e-1d5f6a7b8c9d، وMAC مثل A2:3F:1B:9C:44:D0 (البايت الأول دائماً محلي الإدارة)، وطول hex 16 يُنتج 32 خانة."
            ),
            notes: LocalizedText(
                en: "Uses Swift's standard random generator, fine for testing and general identifiers but not a strong cryptographic source. Hex length is clamped to 1 to 256 bytes, only the last 20 are kept, and there is no network access.",
                ar: "تستخدم مولّد Swift العشوائي القياسي، مناسب للاختبار والمعرّفات العامة لكنه ليس مصدراً تشفيرياً قوياً. طول hex محصور بين 1 و256 بايت، وتُحفَظ آخر 20 نتيجة فقط، ولا اتصال بالشبكة."
            )
        ),
        "qr-generator": ToolHelpContent(
            overview: LocalizedText(
                en: "Turns any text, URL, or data into a crisp QR code shown directly on screen, generated instantly as you type and ready to scan with any camera.",
                ar: "تحوّل أي نص أو رابط أو بيانات إلى رمز QR واضح يظهر مباشرة على الشاشة، يتولّد فوراً أثناء الكتابة وجاهز للمسح بأي كاميرا."
            ),
            howItWorks: LocalizedText(
                en: "Generation uses Apple's built-in CoreImage QR filter, running 100% on-device with no network. The text becomes UTF-8, the code is built at medium error correction, scaled 12x with sharp edges on a white background.",
                ar: "التوليد يستخدم مرشّح QR المدمج في CoreImage من Apple، ويعمل محلياً بالكامل بدون اتصال بالإنترنت. يُحوَّل النص إلى UTF-8، ويُبنى الرمز بتصحيح أخطاء متوسط، ويُكبَّر 12 مرة بحواف حادة على خلفية بيضاء."
            ),
            example: LocalizedText(
                en: "Input https://aswaralmudun.com shows a QR code as you type; scanning it opens that same URL. Empty text produces no code.",
                ar: "إدخال https://aswaralmudun.com يُظهر رمز QR فور الكتابة؛ ومسحه يفتح الرابط نفسه. النص الفارغ لا يُنتج أي رمز."
            ),
            notes: LocalizedText(
                en: "Error correction is fixed at medium and there is no built-in export beyond a screenshot. Available on iOS only, and very long text yields dense codes; everything is local with no server.",
                ar: "تصحيح الأخطاء ثابت عند المتوسط ولا يوجد تصدير مدمج سوى لقطة الشاشة. متاح على iOS فقط، والنصوص الطويلة جداً تُنتج رموزاً كثيفة؛ وكل شيء محلي بلا خادم."
            )
        ),
        "crypto-tools": ToolHelpContent(
            overview: LocalizedText(
                en: "Bundles two functions: computing multiple hashes of any text (MD5, SHA-1, SHA-256, SHA-384, SHA-512), and decoding a JWT's header and payload as pretty JSON with the algorithm and expiry detected.",
                ar: "تجمع وظيفتين: حساب بصمات متعددة لأي نص (MD5، SHA-1، SHA-256، SHA-384، SHA-512)، وفكّ رمز JWT وعرض ترويسته وحمولته بصيغة JSON منسّقة مع كشف الخوارزمية وتاريخ الانتهاء."
            ),
            howItWorks: LocalizedText(
                en: "Runs 100% on-device with no network using Apple's CryptoKit. Hash mode computes all five digests at once as hex. JWT mode base64url-decodes the header and payload and reads alg and exp; no signature verification is performed.",
                ar: "تعمل محلياً بالكامل بدون اتصال بالإنترنت عبر CryptoKit من Apple. وضع البصمات يحسب الخمسة دفعة واحدة بصيغة hex. وضع JWT يفكّ الترويسة والحمولة بترميز base64url ويقرأ alg وexp؛ ولا يُجرى أي تحقق من التوقيع."
            ),
            example: LocalizedText(
                en: "Text hello gives MD5 5d41402abc4b2a76b9719d911017c592 and SHA-256 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824. A JWT with a past exp shows algorithm HS256 and status expired.",
                ar: "النص hello يعطي MD5 5d41402abc4b2a76b9719d911017c592 وSHA-256 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824. رمز JWT بـ exp في الماضي يُظهر الخوارزمية HS256 والحالة منتهٍ."
            ),
            notes: LocalizedText(
                en: "JWT signatures are never verified, so displaying a token does not mean it is trusted. MD5 and SHA-1 are for compatibility only. All computation is on-device; text and tokens are never sent to any server.",
                ar: "لا يُتحقق من توقيع JWT إطلاقاً، فعرض الرمز لا يعني أنه موثوق. MD5 وSHA-1 للتوافق فقط. كل الحساب على الجهاز؛ والنصوص والرموز لا تُرسَل لأي خادم."
            )
        ),
        "hash-id": ToolHelpContent(
            overview: LocalizedText(
                en: "Guesses the likely algorithm(s) that produced a given hash string based on its length, character set, and any leading prefix. It does not crack or verify the hash. Runs 100% on-device with no network.",
                ar: "تُخمّن الخوارزمية أو الخوارزميات التي على الأرجح أنتجت سلسلة تجزئة، اعتماداً على طولها ومجموعة أحرفها والبادئة إن وُجدت. لا تفكّها ولا تتحقق منها. تعمل محلياً بالكامل بدون اتصال بالإنترنت."
            ),
            howItWorks: LocalizedText(
                en: "Pure string logic in three stages: modular-crypt prefixes (like $2y$ for bcrypt), hex length mapping (32 to MD5/NTLM, 40 to SHA-1, 64 to SHA-256, and so on), and base64 shape and length. No crypto library is used.",
                ar: "منطق نصي محض على ثلاث مراحل: بوادئ modular-crypt (مثل $2y$ لـ bcrypt)، وربط الطول الست عشري (32 لـ MD5/NTLM، 40 لـ SHA-1، 64 لـ SHA-256، وهكذا)، وشكل وطول base64. لا تُستخدم أي مكتبة تشفير."
            ),
            example: LocalizedText(
                en: "Input 5d41402abc4b2a76b9719d911017c592 (32 hex chars) yields candidates MD5, NTLM, MD4, LM; input starting $2y$10$ yields bcrypt.",
                ar: "إدخال 5d41402abc4b2a76b9719d911017c592 (32 حرفاً ست عشرياً) يُنتج المرشحين MD5 وNTLM وMD4 وLM؛ وإدخال يبدأ بـ $2y$10$ يُنتج bcrypt."
            ),
            notes: LocalizedText(
                en: "Identification is heuristic by length and shape only, so different algorithms sharing a length cannot be confirmed from length alone. No data leaves the device, and unrecognized strings will not match.",
                ar: "التعرّف استدلالي بالطول والشكل فقط، فالخوارزميات المتشاركة في الطول لا يمكن الجزم بها من الطول وحده. لا تُرسَل أي بيانات خارج الجهاز، والسلاسل غير المعروفة لن تُطابَق."
            )
        )
    ]
}
