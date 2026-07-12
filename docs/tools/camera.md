# IP Camera Viewer · عارض كاميرات IP

> **Category / التصنيف:** Local Network / الشبكة المحلية  
> **Tool ID:** `camera`

---

## نظرة عامة · Overview
**بالعربي:** يعرض هذا الأداة بثًّا مباشرًا من كاميرات IP على شبكتك عبر بروتوكول RTSP، مع دعم اكتشاف الكاميرات تلقائيًّا، والإعداد الذكي عبر ONVIF، والتقاط الصور الثابتة (snapshot)، وتسجيل المقاطع، والتحكّم بالحركة (PTZ)، وعرض عدة كاميرات في شبكة واحدة. يحفظ ملفات الكاميرات محليًّا مع تخزين كلمات المرور في سلسلة المفاتيح (Keychain).
**English:** This tool displays a live feed from IP cameras on your network over the RTSP protocol, with support for automatic camera discovery, smart setup via ONVIF, still snapshots, clip recording, pan/tilt/zoom (PTZ) control, and a multi‑camera grid view. It stores camera profiles locally with passwords kept in the Keychain.

## كيف تعمل · How it works
**بالعربي:** يشغّل التطبيق البث عبر **عميل RTSP مكتوب يدويًّا** فوق إطار Network، لأن AVFoundation في iOS لا يدعم RTSP. يتحدث العميل RTSP عبر TCP: `DESCRIBE` ← تحليل SDP ← `SETUP` (نقل RTP متداخل على نفس اتصال TCP) ← `PLAY`، مع مصادقة Basic/Digest ونبضات إبقاء دورية. تُفكَّك حزم الفيديو (H.264 / H.265) في `VideoDepacketizer` وتُبنى إطارات `CMSampleBuffer` تُعرض في `AVSampleBufferDisplayLayer`. عنوان البث الافتراضي بصيغة `rtsp://<host>[:554]/<path>` — المنفذ القياسي لـ RTSP هو `554`. الإعداد التلقائي يستخدم **ONVIF** (خدمات ويب SOAP على المنفذ `80` افتراضيًّا): `GetDeviceInformation` لجلب المُصنّع والطراز، و`GetProfiles`/`GetStreamUri` لجلب مسار البث ودقّته، و`GetSnapshotUri` للصور الثابتة. أما **اكتشاف الكاميرات** فيتم بمسح الشبكة الفرعية `/24` عبر اختبار اتصال TCP على المنفذ `554` (بدل WS‑Discovery متعدد الإرسال الذي يحتاج entitlement غير متاح لتطبيقات Playgrounds). التحكّم PTZ يُرسَل عبر أوامر ONVIF `ContinuousMove`.
**English:** The app plays the feed via a **hand‑written RTSP client** on top of Network framework, because iOS's AVFoundation has no RTSP support. The client speaks RTSP over TCP: `DESCRIBE` → parse SDP → `SETUP` (RTP interleaved on the same TCP connection) → `PLAY`, with Basic/Digest authentication and periodic keep‑alives. Video packets (H.264 / H.265) are demuxed in a `VideoDepacketizer`, and `CMSampleBuffer` frames are built and rendered in an `AVSampleBufferDisplayLayer`. The stream URL is of the form `rtsp://<host>[:554]/<path>` — RTSP's standard port is `554`. Auto‑setup uses **ONVIF** (SOAP web services on port `80` by default): `GetDeviceInformation` for manufacturer and model, `GetProfiles`/`GetStreamUri` for the stream path and resolution, and `GetSnapshotUri` for still images. **Camera discovery** sweeps the `/24` subnet with a TCP‑connect probe on port `554` (instead of multicast WS‑Discovery, which needs an entitlement unavailable to a Playgrounds‑distributed app). PTZ control is sent via ONVIF `ContinuousMove` commands.

## المدخلات · Inputs
**بالعربي:** يُضاف كل كاميرا كملف يحتوي:
- **الاسم (Name):** تسمية اختيارية؛ يُستخدم المضيف إن تُرك فارغًا.
- **المضيف (Host):** عنوان IP للكاميرا مثل `192.168.8.50` (يمكن اختياره من المضيفين المحفوظين).
- **منفذ RTSP (RTSP Port):** افتراضيًّا `554`.
- **مسار البث (Path):** مثل `/stream1` أو `/Streaming/Channels/101`.
- **منفذ ONVIF (ONVIF Port):** افتراضيًّا `80`.
- **اسم المستخدم/كلمة المرور:** لمصادقة RTSP/ONVIF؛ كلمة المرور تُخزَّن في Keychain.

كما يوفّر زر «فحص» لاكتشاف كاميرات على الشبكة، وزر «ONVIF» لجلب الإعدادات تلقائيًّا داخل نموذج التحرير.
**English:** Each camera is added as a profile with:
- **Name:** optional label; the host is used if left blank.
- **Host:** the camera's IP such as `192.168.8.50` (selectable from saved hosts).
- **RTSP Port:** default `554`.
- **Path:** e.g. `/stream1` or `/Streaming/Channels/101`.
- **ONVIF Port:** default `80`.
- **Username/Password:** for RTSP/ONVIF auth; the password is stored in the Keychain.

There is also a "Scan" button to discover cameras on the network, and an "ONVIF" button inside the editor to fetch settings automatically.

## المخرجات · Outputs
**بالعربي:**
- **مشغّل الفيديو:** صورة حيّة بنسبة 16:9 مع شارة حالة (Live / يتصل / خطأ / خامل)، وأزرار: تسجيل، لقطة ثابتة، ملء الشاشة، إعادة المحاولة، وإيقاف.
- **قائمة الكاميرات المحفوظة:** كل صف يعرض الاسم وعنوان `rtsp://...` مع أزرار تشغيل وتحرير وحذف.
- **قسم PTZ:** يظهر فقط للكاميرات التي كشفت ONVIF دعمها للحركة.
- **عرض الشبكة:** يعرض عدة كاميرات معًا.
- **الصور والتسجيلات:** لقطة ثابتة عبر رابط ONVIF، وملف تسجيل يمكن مشاركته أو حفظه عند الانتهاء.
**English:**
- **Video player:** a live 16:9 image with a status badge (Live / connecting / error / idle), and buttons for record, snapshot, fullscreen, retry, and stop.
- **Saved cameras list:** each row shows the name and the `rtsp://...` URL with play, edit, and delete actions.
- **PTZ section:** appears only for cameras where ONVIF detected motion support.
- **Grid view:** shows several cameras together.
- **Images and recordings:** a still snapshot via the ONVIF URL, and a recording file that can be shared or saved when finished.

## مثال تشغيل · Worked example
**بالعربي:** تفتح قائمة الإضافة وتختار «فحص». تكتشف الأداة `192.168.8.50` بمنفذ `554` مفتوح. تختاره فيُنشأ ملف مسبقًا بعنوانه، ثم تدخل اسم المستخدم `admin` وكلمة المرور، وتضغط «ONVIF» فتُجلب البيانات: المُصنّع `Hikvision`، الطراز `DS-2CD2043`، مع ملف بث بدقّة `2560×1440` ومسار `/Streaming/Channels/101`. تحفظ الكاميرا ثم تضغط تشغيل فيظهر البث المباشر بشارة «Live».
**English:** You open the add menu and pick "Scan." The tool discovers `192.168.8.50` with port `554` open. You select it, a profile is pre‑filled with its host, you enter username `admin` and the password, and tap "ONVIF" to fetch: manufacturer `Hikvision`, model `DS-2CD2043`, a stream profile at `2560×1440` with path `/Streaming/Channels/101`. You save the camera, tap play, and the live feed appears with a "Live" badge.

## ملاحظات وقيود · Notes & limitations
**بالعربي:**
- يتطلب هذا الأداة صلاحية **«الشبكة المحلية»** في iOS للاتصال بالكاميرات ولاكتشافها. لتفعيلها: **الإعدادات ← NetToolbox ← الشبكة المحلية**. بدونها يفشل اكتشاف الكاميرات (نتائج فارغة) وقد يفشل الاتصال بالبث.
- اكتشاف الكاميرات يعتمد على مسح المنفذ `554` عبر TCP لأن WS‑Discovery متعدد الإرسال يحتاج entitlement غير متاح؛ الكاميرات على منفذ RTSP غير قياسي قد لا تُكتشَف تلقائيًّا ويلزم إضافتها يدويًّا.
- يعتمد الإعداد التلقائي على دعم الكاميرا لـ ONVIF؛ إن لم تدعمه أدخِل مسار البث والمنفذ يدويًّا.
- كلمات مرور الكاميرات تُخزَّن في Keychain لا في ملف JSON العادي؛ وتُحذف من Keychain عند حذف الكاميرا.
**English:**
- This tool requires the iOS **Local Network** permission to connect to and discover cameras. Enable it via **Settings ← NetToolbox ← Local Network**. Without it discovery fails (empty results) and the stream connection may fail.
- Camera discovery relies on a TCP sweep of port `554` because multicast WS‑Discovery needs an unavailable entitlement; cameras on a non‑standard RTSP port may not be auto‑discovered and must be added manually.
- Auto‑setup depends on the camera supporting ONVIF; if it does not, enter the stream path and port manually.
- Camera passwords are stored in the Keychain, not the plain JSON file, and are removed from the Keychain when the camera is deleted.
