# SSDP / UPnP Discovery · اكتشاف SSDP / UPnP

> **Category / التصنيف:** Local Network / الشبكة المحلية  
> **Tool ID:** `ssdp`

---

## نظرة عامة · Overview
**بالعربي:** يكتشف هذا الأداة أجهزة UPnP على شبكتك المحلية عبر بروتوكول SSDP (Simple Service Discovery Protocol) — مثل الراوترات (بوابات الإنترنت IGD) وخوادم الوسائط (MediaServer) وأجهزة التلفاز الذكية ومكبّرات الصوت. يرسل استعلام بحث متعدد الإرسال (multicast) ويجمع ردود الأجهزة مع عناوينها وروابط وصفها.
**English:** This tool discovers UPnP devices on your local network via SSDP (Simple Service Discovery Protocol) — such as routers (Internet Gateway Devices, IGD), media servers (MediaServer), smart TVs, and speakers. It sends a multicast search query and collects the devices' replies with their addresses and description URLs.

## كيف تعمل · How it works
**بالعربي:** تفتح الأداة مقبس UDP (`SOCK_DGRAM`) وترسل رسالة `M-SEARCH * HTTP/1.1` عبر HTTPU إلى عنوان البث المتعدد القياسي لـ SSDP وهو `239.255.255.250` على المنفذ `1900`. تحدّد الرسالة `MAN: "ssdp:discover"` و`MX: 2` (أقصى تأخير للرد) و`ST:` (هدف البحث المختار). يُضبط `IP_MULTICAST_TTL` على 2. ثم تستمع لمدة 4 ثوانٍ لالتقاط ردود الأجهزة (بمهلة استقبال ثانية واحدة لكل حزمة ضمن الحلقة). كل رد يُحلَّل لاستخراج ترويسات `LOCATION` (رابط ملف الوصف XML) و`SERVER` (سلسلة الخادم/نظام التشغيل) و`ST` (هدف البحث) و`USN` (المعرّف الفريد للجهاز). تُزال التكرارات حسب `USN`. على iOS يتطلب البث المتعدد صلاحية Multicast Networking؛ بدونها يفشل الإرسال ولا تُرجع أي أجهزة.
**English:** The tool opens a UDP socket (`SOCK_DGRAM`) and sends an `M-SEARCH * HTTP/1.1` message over HTTPU to the standard SSDP multicast address `239.255.255.250` on port `1900`. The message specifies `MAN: "ssdp:discover"`, `MX: 2` (max reply delay), and `ST:` (the chosen search target). `IP_MULTICAST_TTL` is set to 2. It then listens for 4 seconds to collect device replies (with a 1‑second per‑packet receive timeout inside the loop). Each reply is parsed for the `LOCATION` header (the XML description URL), `SERVER` (server/OS string), `ST` (search target), and `USN` (unique device name). Duplicates are removed by `USN`. On iOS, multicast requires the Multicast Networking entitlement; without it the send fails and no devices are returned.

## المدخلات · Inputs
**بالعربي:** قائمة منسدلة لاختيار **هدف البحث (Search Target / ST)**:
- `ssdp:all` — جميع الأجهزة والخدمات (الافتراضي).
- `UPnP root` (`upnp:rootdevice`) — الأجهزة الجذرية فقط.
- `MediaServer` (`urn:schemas-upnp-org:device:MediaServer:1`) — خوادم الوسائط.
- `IGD (router)` (`urn:schemas-upnp-org:device:InternetGatewayDevice:1`) — الراوتر/بوابة الإنترنت.

ثم زر «فحص» لبدء الاكتشاف.
**English:** A dropdown to choose the **Search Target (ST)**:
- `ssdp:all` — all devices and services (default).
- `UPnP root` (`upnp:rootdevice`) — root devices only.
- `MediaServer` (`urn:schemas-upnp-org:device:MediaServer:1`) — media servers.
- `IGD (router)` (`urn:schemas-upnp-org:device:InternetGatewayDevice:1`) — the router/internet gateway.

Then a "Scan" button starts discovery.

## المخرجات · Outputs
**بالعربي:** قائمة بالأجهزة المكتشفة، كل بطاقة تعرض: عنوان IP للجهاز مثل `192.168.1.1`، وسلسلة `SERVER` مثل `Linux/3.14 UPnP/1.0`، ورابط `LOCATION` مثل `http://192.168.1.1:1900/rootDesc.xml`، وهدف البحث `ST` المطابق. إن لم تُرجع نتائج تظهر رسالة «فارغ» بعد انتهاء الفحص.
**English:** A list of discovered devices; each card shows: the device IP such as `192.168.1.1`, the `SERVER` string such as `Linux/3.14 UPnP/1.0`, the `LOCATION` URL such as `http://192.168.1.1:1900/rootDesc.xml`, and the matching `ST` search target. If no results are returned an "empty" message is shown after the scan finishes.

## مثال تشغيل · Worked example
**بالعربي:** تختار `IGD (router)` وتضغط «فحص». بعد أربع ثوانٍ يظهر جهاز واحد: العنوان `192.168.8.1`، الخادم `RT-AC68U UPnP/1.1 MiniUPnPd/2.1`، الموقع `http://192.168.8.1:52869/rootDesc.xml`، وهدف البحث `urn:schemas-upnp-org:device:InternetGatewayDevice:1`. يشير هذا إلى أن راوترك يدعم UPnP لإعادة توجيه المنافذ.
**English:** You pick `IGD (router)` and tap "Scan." After four seconds one device appears: address `192.168.8.1`, server `RT-AC68U UPnP/1.1 MiniUPnPd/2.1`, location `http://192.168.8.1:52869/rootDesc.xml`, and search target `urn:schemas-upnp-org:device:InternetGatewayDevice:1`. This indicates your router supports UPnP for port forwarding.

## ملاحظات وقيود · Notes & limitations
**بالعربي:**
- يتطلب البث المتعدد على iOS صلاحية شبكة، ويستدعي الوصول للشبكة المحلية صلاحية **«الشبكة المحلية»**. لتفعيلها: **الإعدادات ← NetToolbox ← الشبكة المحلية**. بدون الصلاحيات المناسبة يفشل الإرسال المتعدد وتُرجع الأداة قائمة فارغة دون خطأ ظاهر.
- الأجهزة التي لا تدعم UPnP/SSDP أو التي عُطِّل فيها لن تظهر.
- مدة الفحص محدّدة بأربع ثوانٍ؛ الأجهزة البطيئة في الرد قد لا تُلتقط في المحاولة الأولى.
**English:**
- Multicast on iOS requires a networking entitlement, and touching the local network invokes the **Local Network** permission. Enable it via **Settings ← NetToolbox ← Local Network**. Without the appropriate permissions the multicast send fails and the tool returns an empty list with no visible error.
- Devices that do not support UPnP/SSDP, or where it is disabled, will not appear.
- The scan window is fixed at four seconds; slow‑to‑reply devices may be missed on the first attempt.
