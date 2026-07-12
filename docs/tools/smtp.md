# SMTP Probe · فاحص SMTP

> **Category / التصنيف:** Professional / احترافي  
> **Tool ID:** `smtp`

---

## نظرة عامة · Overview
**بالعربي:** أداة تفحص خادم بريد SMTP بإجراء مصافحة `EHLO` قصيرة، فتعرض لافتة الترحيب والقدرات (capabilities) التي يُعلن عنها الخادم. فحص سريع لصحّة الخادم ومعرفة الميزات المدعومة مثل `STARTTLS` و `AUTH` وحجم الرسائل. التنفيذ أصلي بالكامل بدون مكتبات خارجية.

**English:** A tool that probes an SMTP mail server with a short `EHLO` handshake, showing the greeting banner and the capabilities the server advertises. A quick health check that reveals supported features like `STARTTLS`, `AUTH`, and message size. Fully native implementation with no external libraries.

## كيف تعمل · How it works
**بالعربي:** الأداة تفتح اتصال TCP (أو TLS مباشر إن فُعّل) إلى المنفذ `25` افتراضيًا. المنافذ الشائعة الأخرى: `587` (الإرسال مع STARTTLS) و `465` (SMTPS عبر TLS مباشر). البروتوكول هو SMTP النصّي: تقرأ الأداة لافتة الترحيب `220`، ثم ترسل `EHLO nettoolbox.local`، وتقرأ استجابة القدرات (أسطر `250-`)، ثم ترسل `QUIT` وتقرأ الوداع `221`. كل الأوامر تنتهي بـ `\r\n`. تُسجَّل المحادثة كاملة مع بادئات `C:` للأوامر المُرسَلة و `S:` لردود الخادم.

**English:** The tool opens a TCP connection (or direct TLS if enabled) to port `25` by default. Other common ports: `587` (submission with STARTTLS) and `465` (SMTPS over direct TLS). The protocol is text SMTP: the tool reads the `220` greeting, sends `EHLO nettoolbox.local`, reads the capability response (`250-` lines), then sends `QUIT` and reads the `221` goodbye. Every command ends with `\r\n`. The full conversation is logged with `C:` prefixes for sent commands and `S:` for server replies.

## المدخلات · Inputs
- **Host / المضيف:** عنوان خادم البريد · the mail server address.
- **Port / المنفذ:** الافتراضي `25` (استخدم `587` أو `465` حسب الحالة) · Defaults to `25` (use `587` or `465` as appropriate).
- **TLS / التشفير:** مفتاح لبدء اتصال مشفّر مباشر (مناسب للمنفذ `465`) · toggle to start a direct encrypted connection (suited to port `465`).

## المخرجات · Outputs
**بالعربي:** بطاقة "نصّ المحادثة" تعرض تسلسل الحوار كاملًا: لافتة `S: 220 …`، ثم `C: EHLO nettoolbox.local`، ثم أسطر القدرات `S: 250-…`، ثم `C: QUIT` و `S: 221 …`. يوجد زر نسخ للناتج. عند فشل الاتصال أو فراغ الردّ تظهر رسالة خطأ.

**English:** A "transcript" card showing the full dialogue: the `S: 220 …` banner, then `C: EHLO nettoolbox.local`, then the `S: 250-…` capability lines, then `C: QUIT` and `S: 221 …`. A copy button is provided. On connection failure or an empty reply an error message appears.

## مثال تشغيل · Worked example
**بالعربي:** المضيف `smtp.gmail.com`، المنفذ `25`، بدون TLS. المتوقّع نصّ مثل:
```
S: 220 smtp.gmail.com ESMTP ready
C: EHLO nettoolbox.local
S: 250-smtp.gmail.com at your service
S: 250-SIZE 35882577
S: 250-STARTTLS
S: 250 SMTPUTF8
C: QUIT
S: 221 closing connection
```

**English:** Host `smtp.gmail.com`, port `25`, no TLS. Expected transcript like:
```
S: 220 smtp.gmail.com ESMTP ready
C: EHLO nettoolbox.local
S: 250-smtp.gmail.com at your service
S: 250-SIZE 35882577
S: 250-STARTTLS
S: 250 SMTPUTF8
C: QUIT
S: 221 closing connection
```

## ملاحظات وقيود · Notes & limitations
**بالعربي:** الأداة فاحص فقط — تُجري `EHLO` ثم تنهي الجلسة، ولا ترسل أي بريد فعلي ولا تجرّب `STARTTLS` ولا `AUTH`. على المنفذ `25` بدون TLS تكون المحادثة نصّية غير مشفّرة. مفتاح TLS يبدأ اتصالًا مشفّرًا مباشرًا (لا يرقّي عبر STARTTLS)، فهو مناسب للمنفذ `465` لا `587`. مهلة الاتصال `6` ثوانٍ. كل النشاط يبقى على الجهاز عدا الاتصال بالخادم المستهدف.

**English:** The tool is a probe only — it performs `EHLO` then ends the session, sending no actual mail and not exercising `STARTTLS` or `AUTH`. On port `25` without TLS the conversation is plaintext and unencrypted. The TLS toggle starts a direct encrypted connection (it does not upgrade via STARTTLS), so it suits port `465`, not `587`. The connection timeout is `6` seconds. All activity stays on the device except the connection to the target server.
