# WebSocket Client · عميل WebSocket

> **Category / التصنيف:** Professional / احترافي  
> **Tool ID:** `websocket`

---

## نظرة عامة · Overview
**بالعربي:** أداة لاختبار خوادم WebSocket: تفتح اتصالًا حيًّا ثنائي الاتجاه، ترسل رسائل نصّية، وتعرض كل ما يصل من الخادم فور وصوله. مفيدة لتجربة نقاط نهاية `ws`/`wss`، وفحص خوادم الصدى (echo)، وتصحيح تطبيقات الوقت الحقيقي. تعتمد على `URLSessionWebSocketTask` الأصلي في iOS بدون مكتبات خارجية.

**English:** A tool for testing WebSocket servers: it opens a live bidirectional connection, sends text messages, and displays everything the server sends as it arrives. Useful for trying `ws`/`wss` endpoints, checking echo servers, and debugging real-time apps. Built on the native iOS `URLSessionWebSocketTask` with no external libraries.

## كيف تعمل · How it works
**بالعربي:** تقبل الأداة عنوان URL بمخطّط `ws://` (غير مشفّر) أو `wss://` (مشفّر عبر TLS). المنفذ غير مطلوب صراحةً؛ يُشتق من المخطّط والعنوان (افتراضيًا `80` لـ `ws` و `443` لـ `wss`). تُنشئ جلسة `URLSession` عابرة (ephemeral) ومهمّة WebSocket، فتتولّى ترقية HTTP إلى WebSocket ومصافحة البروتوكول تلقائيًا. بعد فتح الاتصال (حدث `open`) تبدأ حلقة استقبال مستمرّة تُبلّغ عن الرسائل النصّية والثنائية وأحداث الإغلاق والأخطاء. الرسائل النصّية تُرسَل عبر `send(.string)`. عند الإغلاق تُلغى المهمّة برمز `goingAway`.

**English:** The tool accepts a URL with the `ws://` (unencrypted) or `wss://` (TLS-encrypted) scheme. The port is not entered explicitly; it is derived from the scheme and address (default `80` for `ws`, `443` for `wss`). It creates an ephemeral `URLSession` and a WebSocket task, which handle the HTTP-to-WebSocket upgrade and protocol handshake automatically. After the connection opens (an `open` event), a continuous receive loop reports text and binary messages plus close and error events. Text messages are sent via `send(.string)`. On close the task is cancelled with the `goingAway` code.

## المدخلات · Inputs
- **URL / العنوان:** نقطة نهاية WebSocket، مثل `wss://echo.websocket.events` (القيمة الافتراضية) · a WebSocket endpoint, e.g. `wss://echo.websocket.events` (the default). يجب أن يبدأ بـ `ws://` أو `wss://` وإلا تظهر رسالة خطأ.
- **Message / الرسالة:** نصّ يُرسَل إلى الخادم بعد الاتصال · text sent to the server after connecting.

## المخرجات · Outputs
**بالعربي:** سجلّ مُلوَّن يعرض كل حدث: الرسائل المُرسَلة (سهم لأعلى)، والواردة (سهم لأسفل)، ورسائل النظام مثل "جارٍ الاتصال/متّصل/أُغلق" (دائرة معلومات)، والأخطاء (مثلّث تحذير). الرسائل الثنائية تظهر كـ `‹N bytes›`. يُحتفَظ بآخر 300 مُدخَلة، وهناك زر لمسح السجلّ.

**English:** A color-coded log showing every event: sent messages (up arrow), received messages (down arrow), system messages like "connecting/connected/closed" (info circle), and errors (warning triangle). Binary messages appear as `‹N bytes›`. The last 300 entries are kept, and a clear button empties the log.

## مثال تشغيل · Worked example
**بالعربي:** العنوان `wss://echo.websocket.events`، ثم إرسال `hello`. المتوقّع: رسالة نظام "متّصل"، ثم مُدخَلة مُرسَلة `hello`، ثم مُدخَلة واردة `hello` (لأن الخادم خادم صدى يعيد ما يستقبله).

**English:** URL `wss://echo.websocket.events`, then send `hello`. Expected: a "connected" system message, a sent entry `hello`, then a received entry `hello` (since it is an echo server that returns what it receives).

## ملاحظات وقيود · Notes & limitations
**بالعربي:** استخدم `wss://` دائمًا على الشبكات العامة لأن `ws://` غير مشفّر ويكشف الرسائل. الأداة ترسل نصًّا فقط (لا يمكن تأليف إطارات ثنائية)، وتعرض الواردة الثنائية كعدّ بايتات فقط. الجلسة عابرة فلا تُخزَّن كوكيز أو ذاكرة مؤقتة. حجم السجلّ محدود بـ 300 مُدخَلة والقديم يُزال تلقائيًا. كل النشاط يبقى على الجهاز عدا الاتصال بالخادم المستهدف.

**English:** Always use `wss://` on public networks, since `ws://` is unencrypted and exposes messages. The tool sends text only (you cannot compose binary frames) and shows inbound binary as a byte count only. The session is ephemeral, so no cookies or cache are stored. The log is capped at 300 entries with old ones removed automatically. All activity stays on the device except the connection to the target server.
