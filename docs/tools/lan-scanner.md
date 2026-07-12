# LAN Scanner (Bonjour) · فاحص الشبكة المحلية (Bonjour)

> **Category / التصنيف:** Local Network / الشبكة المحلية  
> **Tool ID:** `lan-scanner`

---

## نظرة عامة · Overview
**بالعربي:** يكتشف هذا الفاحص الأجهزة والخدمات المُعلَنة على شبكتك المحلية عبر Bonjour/mDNS — مثل خوادم الويب و SSH ومشاركة الملفات و AirPlay والطابعات و Chromecast و HomeKit. لكل خدمة يعرض الاسم والنوع، ثم يحلّها في الخلفية إلى عنوان `host:port` فعلي، مع إمكانية حفظها في المضيفين المحفوظين.
**English:** This scanner discovers devices and services advertised on your local network via Bonjour/mDNS — such as web servers, SSH, file sharing, AirPlay, printers, Chromecast, and HomeKit. For each service it shows the name and type, then resolves it in the background to a concrete `host:port` address, with the option to save it to Saved Hosts.

## كيف تعمل · How it works
**بالعربي:** تستخدم الأداة `NWBrowser` من إطار Network للبحث عن خدمات Bonjour عبر mDNS (multicast DNS على المنفذ `5353`). تُطلق متصفّحًا منفصلًا لكل نوع خدمة من قائمة ثابتة تشمل: `_http._tcp`، `_https._tcp`، `_ssh._tcp`، `_smb._tcp`، `_airplay._tcp`، `_raop._tcp`، `_ipp._tcp`، `_printer._tcp`، `_googlecast._tcp`، `_rfb._tcp`، `_device-info._tcp`، `_homekit._tcp`. يُفعَّل `includePeerToPeer` لاكتشاف الأجهزة عبر AWDL أيضًا. عند العثور على خدمة تُحلَّل إلى host+port فعليين عبر `NWConnection` بمهلة 4 ثوانٍ. تدوم نافذة الاكتشاف 6 ثوانٍ ثم تتوقف تلقائيًا. تُقرأ سجلات TXT الوصفية وتُعرض. يتطلب iOS أن يُعلن التطبيق عن أنواع خدمات Bonjour التي يبحث عنها وعن وصف استخدام الشبكة المحلية؛ بدونها يعيد النظام قائمة فارغة.
**English:** The tool uses Network framework's `NWBrowser` to look up Bonjour services over mDNS (multicast DNS on port `5353`). It launches a separate browser for each service type from a fixed list including: `_http._tcp`, `_https._tcp`, `_ssh._tcp`, `_smb._tcp`, `_airplay._tcp`, `_raop._tcp`, `_ipp._tcp`, `_printer._tcp`, `_googlecast._tcp`, `_rfb._tcp`, `_device-info._tcp`, `_homekit._tcp`. `includePeerToPeer` is enabled to also discover devices over AWDL. When a service is found it is resolved to a concrete host+port via `NWConnection` with a 4‑second timeout. The discovery window runs for 6 seconds then stops automatically. TXT metadata records are read and displayed. iOS requires the app to declare the Bonjour service types it browses and a Local Network usage description; without them the system returns an empty list.

## المدخلات · Inputs
**بالعربي:** لا توجد حقول إدخال. زر «فحص» يبدأ الاكتشاف، وزر «إيقاف» يوقفه يدويًّا قبل انتهاء المهلة. أنواع الخدمات ثابتة وغير قابلة للتعديل من الواجهة.
**English:** No input fields. A "Scan" button starts discovery, and a "Stop" button ends it manually before the timeout. The service types are fixed and not editable from the UI.

## المخرجات · Outputs
**بالعربي:** قائمة بالخدمات المكتشفة، كل صف يعرض: أيقونة ووصف ودّي للنوع (مثل «Printer» أو «SSH»)، واسم الخدمة، والعنوان المحلول `host:port` عند اكتماله (مثل `192.168.1.15:22`)، مع زر إشارة مرجعية لحفظ المضيف. تُعرض أسطر `مفتاح=قيمة` من سجل TXT أسفل كل خدمة. كما يُعرض عدّاد بعدد الخدمات وسجل مختصر بآخر عمليات الفحص.
**English:** A list of discovered services; each row shows: an icon and friendly type label (e.g. "Printer" or "SSH"), the service name, and the resolved `host:port` once complete (e.g. `192.168.1.15:22`), with a bookmark button to save the host. TXT record `key=value` lines are shown beneath each service. A count of services and a short history of recent scans are also displayed.

## مثال تشغيل · Worked example
**بالعربي:** تضغط «فحص» على شبكة منزلية. خلال ست ثوانٍ تظهر: `Apple TV` (AirPlay) على `192.168.8.30:7000`، طابعة `HP LaserJet` (IPP) على `192.168.8.45:631` مع سطر TXT `rp=ipp/print`، وخادم `raspberrypi` (SSH) على `192.168.8.60:22`. تنقر أيقونة الإشارة المرجعية بجانب الراسبيري باي لحفظه في المضيفين المحفوظين.
**English:** You tap "Scan" on a home network. Within six seconds it lists: `Apple TV` (AirPlay) at `192.168.8.30:7000`, an `HP LaserJet` printer (IPP) at `192.168.8.45:631` with TXT line `rp=ipp/print`, and a `raspberrypi` host (SSH) at `192.168.8.60:22`. You tap the bookmark icon next to the Raspberry Pi to save it to Saved Hosts.

## ملاحظات وقيود · Notes & limitations
**بالعربي:**
- يتطلب هذا الفاحص صلاحية **«الشبكة المحلية»** في iOS. لتفعيلها: **الإعدادات ← NetToolbox ← الشبكة المحلية**. بدون الصلاحية يعيد النظام قائمة فارغة تمامًا دون خطأ ظاهر.
- يكتشف فقط الأجهزة التي تُعلن عن نفسها عبر Bonjour/mDNS؛ الأجهزة الصامتة لن تظهر — استخدم «فاحص مدى IP» لمسح كامل بالـ ping.
- قد يستغرق تحليل العنوان لحظات إضافية بعد ظهور اسم الخدمة، وقد يفشل لبعض الخدمات فيبقى النوع ظاهرًا دون عنوان.
**English:**
- This scanner requires the iOS **Local Network** permission. Enable it via **Settings ← NetToolbox ← Local Network**. Without the permission the system returns a completely empty list with no visible error.
- It only discovers devices that advertise themselves via Bonjour/mDNS; silent devices will not appear — use the "IP Range Scanner" for a full ping sweep.
- Address resolution may take an extra moment after the service name appears, and it can fail for some services, leaving the type shown without an address.
