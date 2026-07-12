# Telnet Client · عميل Telnet

> **Category / التصنيف:** Professional / احترافي  
> **Tool ID:** `telnet`

---

## نظرة عامة · Overview
**بالعربي:** عميل Telnet بسيط يفتح جلسة نصّية حيّة مع خادم بعيد على المنفذ `23` افتراضيًا. مفيد لاختبار الخدمات النصّية، وقراءة لافتات الترحيب (banners)، والتفاعل مع المعدّات القديمة أو أجهزة الشبكة التي تدعم Telnet. التنفيذ أصلي عبر إطار `Network` بدون مكتبات خارجية.

**English:** A simple Telnet client that opens a live text session with a remote server on port `23` by default. Useful for testing text services, reading welcome banners, and interacting with legacy equipment or network devices that speak Telnet. Implemented natively over the `Network` framework with no external libraries.

## كيف تعمل · How it works
**بالعربي:** الأداة تفتح اتصال TCP عاديًا (بدون تشفير) إلى المضيف والمنفذ `23`. البروتوكول هو Telnet وفق RFC 854. عند وصول بيانات، تمرّ عبر معالج `TelnetProtocol` الذي يفصل النص القابل للعرض عن أوامر التفاوض على الخيارات (تسلسلات `IAC` بالرمز `255`). يردّ العميل تلقائيًا برفض مهذّب لكل الخيارات: على `DO` يردّ `WONT`، وعلى `WILL` يردّ `DONT`، ويتخطّى مقاطع التفاوض الفرعي (`SB … SE`) — مما يبقي الجلسة في وضع السطر (line mode). البايت `0xFF` المضاعَف يُفكّ كحرف حرفي. الأوامر المُدخَلة تُرسَل مع نهاية سطر `\r\n`.

**English:** The tool opens a plain (unencrypted) TCP connection to the host and port `23`. The protocol is Telnet per RFC 854. Incoming data passes through the `TelnetProtocol` processor, which separates displayable text from option-negotiation commands (`IAC` sequences, byte `255`). The client automatically responds with a polite refusal to every option: to `DO` it replies `WONT`, to `WILL` it replies `DONT`, and it skips subnegotiation blocks (`SB … SE`) — keeping the session in line mode. A doubled `0xFF` byte is decoded as a literal character. Typed commands are sent with a `\r\n` line ending.

## المدخلات · Inputs
- **Host / المضيف:** اسم النطاق أو IP للخادم · Hostname or IP of the server.
- **Port / المنفذ:** افتراضيًا `23` · Defaults to `23`.
- **Command / الأمر:** سطر نصّي يُرسَل إلى الخادم بعد الاتصال (متبوعًا بـ `\r\n`) · a text line sent to the server after connecting (followed by `\r\n`).

## المخرجات · Outputs
**بالعربي:** نافذة طرفية خضراء تعرض نص الجلسة المتجدّد حيّا (كل ما يرسله الخادم بعد تنظيفه من أوامر التفاوض). تظهر شارة "متّصل" عند نجاح الاتصال، وزر لقطع الاتصال. تُرسَل ردود التفاوض تلقائيًا في الخلفية ولا تظهر في النص.

**English:** A green terminal pane showing the live transcript (everything the server sends, cleaned of negotiation commands). A "connected" badge appears on success, along with a disconnect button. Negotiation replies are sent automatically in the background and do not appear in the transcript.

## مثال تشغيل · Worked example
**بالعربي:** المضيف `telehack.com`، المنفذ `23`. بعد الاتصال تظهر لافتة ترحيب نصّية. اكتب `help` واضغط إرسال لترى قائمة الأوامر المتاحة تظهر في نافذة الطرفية.

**English:** Host `telehack.com`, port `23`. After connecting a text welcome banner appears. Type `help` and send to see the list of available commands appear in the terminal pane.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** Telnet بروتوكول نصّي عادي غير مشفّر بالكامل — كل شيء، بما في ذلك أي كلمات مرور، يُرسَل بوضوح عبر الشبكة. لا تستخدمه للدخول إلى أنظمة حسّاسة على شبكات غير موثوقة؛ استخدم SSH بدلًا منه. العميل يرفض جميع خيارات Telnet (وضع السطر فقط) ولا يدعم أنماطًا مثل الطرفية الكاملة أو الصدى المحلّي. الجلسة والنص يبقيان على الجهاز.

**English:** Telnet is a plaintext, entirely unencrypted protocol — everything, including any passwords, is sent in the clear across the network. Do not use it to log into sensitive systems over untrusted networks; use SSH instead. The client refuses all Telnet options (line mode only) and does not support modes like full-screen terminal or local echo. The session and transcript stay on the device.
