# Wi‑Fi Info · معلومات الواي‑فاي

> **Category / التصنيف:** Local Network / الشبكة المحلية  
> **Tool ID:** `wifi-info`

---

## نظرة عامة · Overview
**بالعربي:** تعرض هذه الأداة ما يمكن لتطبيق iOS الحصول عليه عن اتصال Wi‑Fi الحالي: عنوان IP الخاص بالجهاز على واجهة Wi‑Fi (`en0`)، وعنوان IP العام مع مزوّد الخدمة. كما توضح بصراحة القياسات التي تحجبها منظومة iOS (مثل SSID وقوة الإشارة والقناة)، وتوفّر زرًّا لتشغيل اختصار Shortcuts يمكنه جلب بعض هذه التفاصيل.
**English:** This tool shows what an iOS app can obtain about the current Wi‑Fi connection: the device's IP address on the Wi‑Fi interface (`en0`) and the public IP with ISP. It also honestly lists the metrics that iOS hides from apps (such as SSID, signal strength, and channel), and offers a button to run a Shortcuts automation that can retrieve some of those details.

## كيف تعمل · How it works
**بالعربي:** واجهة Wi‑Fi على iOS تُسمّى `en0`. تقرأ الأداة عناوين الجهاز محليًا عبر `getifaddrs()` وتُرشِّح لعنوان `en0` من نوع `IPv4`؛ وإن لم يوجد ترجع لكل عناوين `IPv4`. الـ IP العام يُجلب عبر HTTPS من `https://ipwho.is/`. القياسات اللاسلكية التفصيلية (SSID، قوة الإشارة RSSI، القناة، النطاق 2.4/5 GHz، الجيل Wi‑Fi، سرعة الوصلة، البوابة، مُصنّع الراوتر) غير متاحة لتطبيقات iOS العادية بسبب قيود الخصوصية، لذا تُعرض في قائمة «غير متاح» مع قفل. لتجاوز ذلك جزئيًّا توفّر الأداة زرّين يفتحان تطبيق Shortcuts عبر مخطط الروابط `shortcuts://run-shortcut?name=...` (لتشغيل اختصار باسم `NetToolbox WiFi`) و`shortcuts://create-shortcut` (لإنشاء اختصار جديد)، لأن إجراءات Shortcuts النظامية تستطيع قراءة اسم الشبكة.
**English:** The Wi‑Fi interface on iOS is named `en0`. The tool reads the device's addresses on‑device via `getifaddrs()` and filters for the `en0` `IPv4` address; if absent it falls back to all `IPv4` addresses. The public IP is fetched over HTTPS from `https://ipwho.is/`. Detailed wireless metrics (SSID, RSSI signal, channel, 2.4/5 GHz band, Wi‑Fi generation, link speed, gateway, router vendor) are not available to ordinary iOS apps due to privacy restrictions, so they are shown in an "unavailable" list with a lock. To partly work around this, the tool offers two buttons that open the Shortcuts app via the URL scheme `shortcuts://run-shortcut?name=...` (to run a shortcut named `NetToolbox WiFi`) and `shortcuts://create-shortcut` (to create a new one), because system Shortcuts actions can read the network name.

## المدخلات · Inputs
**بالعربي:** لا توجد حقول إدخال. الإجراءات المتاحة: زر «تشغيل الاختصار» وزر «إنشاء اختصار»، والسحب للأسفل لإعادة التحديث.
**English:** No input fields. Available actions: a "Run shortcut" button, a "Create shortcut" button, and pull‑to‑refresh.

## المخرجات · Outputs
**بالعربي:**
- **بطاقة المتاح:** حالة الاتصال، وعنوان جهازك على Wi‑Fi مثل `192.168.8.101`، والـ IP العام ومزوّد الخدمة.
- **بطاقة الاختصار:** تلميح واسم الاختصار المتوقّع `"NetToolbox WiFi"`.
- **بطاقة القيود:** قائمة بالقياسات المحجوبة، كلٌّ منها بعلامة قفل ونص «غير متاح»: قوة الإشارة، القناة، النطاق، الجيل، سرعة الوصلة، SSID، البوابة، مُصنّع الراوتر.
**English:**
- **Available card:** connection status, your Wi‑Fi IP such as `192.168.8.101`, plus the public IP and ISP.
- **Shortcut card:** a hint and the expected shortcut name `"NetToolbox WiFi"`.
- **Limitations card:** a list of the hidden metrics, each with a lock icon and "not available" label: signal, channel, band, generation, link speed, SSID, gateway, router vendor.

## مثال تشغيل · Worked example
**بالعربي:** على شبكة مكتب عبر Wi‑Fi، تُظهر البطاقة الأولى: «Wi‑Fi»، عنوان الجهاز `10.0.5.23`، الـ IP العام `85.194.x.x`، ISP: `Mobily`. تعرض بطاقة القيود ثمانية صفوف مقفلة. عند الضغط على «تشغيل الاختصار» ينتقل النظام إلى تطبيق Shortcuts ويشغّل الاختصار `NetToolbox WiFi` إن كان موجودًا.
**English:** On an office Wi‑Fi network the first card shows: "Wi‑Fi," device address `10.0.5.23`, public IP `85.194.x.x`, ISP `Mobily`. The limitations card shows eight locked rows. Tapping "Run shortcut" hands off to the Shortcuts app and runs the `NetToolbox WiFi` shortcut if it exists.

## ملاحظات وقيود · Notes & limitations
**بالعربي:**
- قراءة عنوان `en0` لا تتطلب صلاحية خاصة، لكن أدوات الاكتشاف الأخرى في التطبيق تتطلب صلاحية «الشبكة المحلية». لتفعيلها: **الإعدادات ← NetToolbox ← الشبكة المحلية**، وبدونها تُرجع تلك الأدوات نتائج فارغة.
- SSID وقوة الإشارة والقناة وسرعة الوصلة غير متاحة لتطبيقات iOS العادية؛ هذا قيد نظامي وليس عيبًا في الأداة.
- زر الاختصار يتطلب أن يكون تطبيق Shortcuts مثبَّتًا وأن يكون الاختصار المسمّى موجودًا لدى المستخدم.
**English:**
- Reading the `en0` address needs no special permission, but the other discovery tools in the app require the Local Network permission. Enable it via **Settings ← NetToolbox ← Local Network**; without it those tools return empty results.
- SSID, signal, channel, and link speed are not available to ordinary iOS apps; this is a system limitation, not a tool defect.
- The shortcut buttons require the Shortcuts app to be installed and the named shortcut to exist in the user's library.
