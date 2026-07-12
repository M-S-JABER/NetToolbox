# CoAP Client · عميل CoAP

> **Category / التصنيف:** Professional / احترافي  
> **Tool ID:** `coap`

---

## نظرة عامة · Overview
**بالعربي:** عميل مبسّط لبروتوكول CoAP (المعرّف في RFC 7252) المستخدم في أجهزة إنترنت الأشياء المحدودة الموارد. يرسل طلب `GET` مؤكَّداً (Confirmable) إلى مورد على منفذ UDP رقم `5683` ويعرض رمز الاستجابة والحمولة النصية.
**English:** A minimal client for CoAP (RFC 7252), the protocol used by constrained IoT devices. It sends a Confirmable `GET` request to a resource over UDP port `5683` and displays the response code and text payload.

## كيف تعمل · How it works
**بالعربي:** تبني الأداة رزمة CoAP ثنائية يدوياً: رأس بطول 4 بايت (الإصدار 1، النوع CON، رمز `0.01` أي GET، ومعرّف رسالة عشوائي). ثم يُقسَّم المسار على `/` وتُشفَّر كل قطعة كخيار Uri-Path (رقم الخيار 11) بصيغة delta/length القياسية. تُرسَل الرزمة عبر UDP (بمهلة 5 ثوانٍ) عبر آلية `UDPExchange`. عند وصول الرد يُقرأ البايت الثاني كرمز استجابة ويُحوَّل إلى الصيغة `class.detail` مثل `2.05`، وإذا وُجد الفاصل `0xFF` تُقرأ الحمولة النصية بعده.
**English:** The tool hand-builds a binary CoAP packet: a 4-byte header (version 1, type CON, code `0.01` = GET, and a random message ID). The path is split on `/` and each segment is encoded as a Uri-Path option (option number 11) using the standard delta/length nibble format. The packet is sent over UDP (5-second timeout) via the `UDPExchange` helper. On reply, the second byte is read as the response code and rendered as `class.detail` (e.g. `2.05`); if the `0xFF` payload marker is present, the text after it is read as the payload.

## المدخلات · Inputs
- **المضيف / Host:** عنوان جهاز أو خادم CoAP · CoAP device or server address.
- **المنفذ / Port:** الافتراضي `5683` (منفذ CoAP القياسي فوق UDP) · Default `5683` (standard CoAP port over UDP).
- **المسار / Path:** مسار المورد بدون بادئة السكيمة، الافتراضي `test` (مثل `.well-known/core` أو `sensors/temp`) · Resource path without the scheme prefix, default `test` (e.g. `.well-known/core` or `sensors/temp`).

## المخرجات · Outputs
**بالعربي:** شارة حالة (خضراء للرموز التي تبدأ بـ 2 وإلا تحذيرية) مع رمز الاستجابة مثل `2.05` (المحتوى)، `4.04` (غير موجود)، `4.05` (غير مسموح). إن وُجدت حمولة نصية تُعرض أسفل الرمز مع إمكانية النسخ.
**English:** A status badge (green for 2.xx codes, otherwise warning) with the response code such as `2.05` (Content), `4.04` (Not Found), `4.05` (Method Not Allowed). If a text payload exists, it is shown below the code and can be copied.

## مثال تشغيل · Worked example
**بالعربي:** الإدخال: المضيف `coap.me`، المنفذ `5683`، المسار `.well-known/core`. النتيجة المتوقعة: رمز `2.05` وحمولة تسرد الموارد مثل `</large>;rt="Text",</time>;if="clock"`.
**English:** Input: host `coap.me`, port `5683`, path `.well-known/core`. Expected result: code `2.05` with a payload listing resources such as `</large>;rt="Text",</time>;if="clock"`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** يدعم هذا العميل طلبات `GET` فقط، ولا يدعم DTLS (منفذ 5684 المؤمّن) ولا Block-wise transfer للحمولات الكبيرة ولا آلية المراقبة (Observe). الطلب مؤكَّد (CON) لكن لا تُعاد المحاولة تلقائياً عند فقد الرزمة؛ ينتهي بمهلة 5 ثوانٍ. بروتوكول UDP لا يضمن الوصول.
**English:** This client supports `GET` requests only — no DTLS (secure port 5684), no block-wise transfer for large payloads, and no Observe. The request is Confirmable (CON) but there is no automatic retransmission on packet loss; it times out after 5 seconds. UDP does not guarantee delivery.
