# Syslog Receiver · مستقبِل Syslog

> **Category / التصنيف:** Professional / احترافي  
> **Tool ID:** `syslog`

---

## نظرة عامة · Overview
**بالعربي:** مستقبِل رسائل Syslog يفتح منفذ UDP محلياً على الجهاز وينتظر الرسائل الواردة من الأجهزة الشبكية (راوترات، سويتشات، خوادم). لكل رسالة يستخرج مستوى الخطورة من بادئة الأولوية `<PRI>` ويعرض المرسِل والنص. المنفذ الافتراضي `5140`.
**English:** A Syslog receiver that binds a local UDP port on the device and waits for inbound messages from network devices (routers, switches, servers). For each message it extracts the severity level from the `<PRI>` priority prefix and displays the sender and text. The default port is `5140`.

## كيف تعمل · How it works
**بالعربي:** هذه أداة **مستقبِلة**: تربط مقبس UDP على المنفذ المحدد محلياً وتبقى في وضع الإصغاء حتى ترد رزم من الشبكة — الأداة لا تبادر بأي اتصال، بل يجب توجيه الأجهزة الأخرى لإرسال سجلاتها إلى عنوان IP الخاص بجهازك وهذا المنفذ. عند وصول رزمة يُفكَّك النص كـ UTF-8، ثم إذا بدأ بـ `<` وانتهى الرقم بـ `>` تُحسب الخطورة من قيمة PRI حسب المعادلة `PRI % 8` وتُطابق قائمة الخطورة القياسية (RFC 3164/5424): `emerg, alert, crit, err, warning, notice, info, debug`. تُحفظ آخر 300 رسالة، وتظهر الأحدث في الأعلى.
**English:** This is a **receiver** tool: it binds a local UDP socket on the chosen port and stays in listening mode until packets arrive from the network — the tool never initiates a connection; other devices must be configured to send their logs to your device's IP address and this port. When a packet arrives it is decoded as UTF-8, and if it starts with `<` and the number closes with `>`, severity is computed from the PRI value as `PRI % 8` and matched against the standard severity list (RFC 3164/5424): `emerg, alert, crit, err, warning, notice, info, debug`. The last 300 messages are kept, newest on top.

## المدخلات · Inputs
- **المنفذ / Port:** المنفذ المحلي الذي يُصغى عليه، الافتراضي `5140` · The local port to listen on, default `5140`.
- **زر الإصغاء/الإيقاف / Listen–Stop button:** يبدأ أو يوقف الاستقبال · Starts or stops receiving.

**بالعربي:** ملاحظة: منفذ Syslog القياسي هو `514`، لكن الأنظمة عادةً تمنع ربط المنافذ أدنى من 1024 دون صلاحيات مرتفعة، لذا الافتراضي هو `5140` غير المتميّز؛ وجّه المرسِلين إليه.
**English:** Note: the standard Syslog port is `514`, but systems typically forbid binding ports below 1024 without elevated privileges, so the default is the unprivileged `5140`; point senders at it.

## المخرجات · Outputs
**بالعربي:** قائمة رسائل، كل عنصر يعرض مستوى الخطورة بحروف كبيرة (إن أمكن استخراجه)، عنوان المرسِل، ونص الرسالة الكامل القابل للتحديد والنسخ. زر لمسح القائمة. تظهر شارة "يُصغي" أثناء التشغيل.
**English:** A list of messages; each row shows the severity level in uppercase (when extractable), the sender address, and the full selectable message text. A button clears the list. A "listening" badge shows while active.

## مثال تشغيل · Worked example
**بالعربي:** ابدأ الإصغاء على `5140`، ثم على راوتر أرسل السجلات إلى `عنوان-الجهاز:5140`. رسالة واردة مثل `<134>Jul 12 10:15:02 router1 sshd[4021]: Accepted password for admin` تظهر بخطورة `INFO` (134 % 8 = 6) مع المرسِل ونص الحدث.
**English:** Start listening on `5140`, then configure a router to send logs to `device-ip:5140`. An inbound message like `<134>Jul 12 10:15:02 router1 sshd[4021]: Accepted password for admin` appears with severity `INFO` (134 % 8 = 6), the sender, and the event text.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** الأداة لا تستقبل شيئاً ما لم تُعِدّ الأجهزة لإرسال Syslog إلى جهازك؛ وقد يمنع الجدار الناري أو شبكة الجوّال وصول الرزم. لا تدعم Syslog فوق TCP أو TLS (منفذ 6514). تُخزَّن الرسائل في الذاكرة فقط (بحدّ 300) ولا تُحفظ على القرص. أثناء الإصغاء لا يمكن تغيير المنفذ.
**English:** The tool receives nothing unless devices are configured to send Syslog to your device; a firewall or cellular network may block the packets. It does not support Syslog over TCP or TLS (port 6514). Messages live in memory only (capped at 300) and are not persisted to disk. The port cannot be changed while listening.
