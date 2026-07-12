# Banner Grab · التقاط لافتة الخدمة

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `banner-grab`

---

## نظرة عامة · Overview
**بالعربي:** أداة محلية تتصل بمنفذ TCP وتقرأ ما تعلنه الخدمة عند الاتصال (لافتات SSH/FTP/SMTP)، أو ردّها على سطر تحقيق اختياري (مثل طلب HTTP). تساعد في تحديد نوع الخدمة وإصدارها العامل خلف منفذ ما.

**English:** A local tool that connects to a TCP port and reads whatever the service announces on connect (SSH/FTP/SMTP banners), or its reply to an optional probe line (e.g. an HTTP request). It helps identify the service type and version running behind a port.

## كيف تعمل · How it works
**بالعربي:** تفتح الأداة `TCPConnection` نحو المضيف والمنفذ المُدخَلين بمهلة `5` ثوانٍ (مع دعم TLS اختياري). إذا أدخلتَ سطر تحقيق غير فارغ، تُرسله متبوعًا بـ `\r\n\r\n`. ثم تقرأ كل ما ترجعه الخدمة عبر `receiveAll` وتعرضه نصًّا. لا يوجد خادم خارجي — الاتصال مباشر من الجهاز إلى الهدف. عند تفعيل TLS يجري الاتصال عبر طبقة TLS (مناسب لمنافذ مثل `443` أو `465` أو `993`).

**English:** The tool opens a `TCPConnection` to the entered host and port with a `5`-second timeout (with optional TLS support). If you enter a non-empty probe line, it is sent followed by `\r\n\r\n`. It then reads everything the service returns via `receiveAll` and displays it as text. There is no external server — the connection is direct from the device to the target. With TLS enabled, the connection runs over a TLS layer (suitable for ports like `443`, `465`, or `993`).

## المدخلات · Inputs
- **Host / المضيف:** اسم النطاق أو عنوان IP للهدف · target hostname or IP.
- **Port / المنفذ:** رقم منفذ TCP، الافتراضي `22` · TCP port number (default `22`).
- **TLS / تشفير TLS:** مفتاح لتغليف الاتصال بطبقة TLS · toggle to wrap the connection in TLS.
- **Probe / سطر التحقيق:** نص اختياري يُرسَل بعد الاتصال، مثل `GET / HTTP/1.0` · optional line sent after connecting.

## المخرجات · Outputs
**بالعربي:** بطاقة تعرض الاستجابة النصّية الكاملة من الخدمة (قابلة للتحديد ومع زر نسخ). إذا لم تُرجِع الخدمة أي بيانات تظهر رسالة «فارغ»، وعند فشل الاتصال أو المهلة تظهر رسالة الخطأ.

**English:** A card showing the full text response from the service (selectable, with a copy button). If the service returns no data, an "empty" message appears; on connection failure or timeout, an error message is shown.

## مثال تشغيل · Worked example
**بالعربي:** المضيف `github.com`، المنفذ `22`، بلا تحقيق. الناتج النموذجي هو لافتة SSH مثل `SSH-2.0-babeld-...`. مثال آخر: المضيف `example.com`، المنفذ `80`، مع سطر تحقيق `GET / HTTP/1.0` يعيد ترويسات استجابة HTTP.

**English:** Host `github.com`, port `22`, no probe. Typical output is an SSH banner like `SSH-2.0-babeld-...`. Another example: host `example.com`, port `80`, with probe line `GET / HTTP/1.0` returns HTTP response headers.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** الخدمات التي لا تعلن لافتة تلقائيًا (كثير من خوادم HTTP) تتطلّب سطر تحقيق للحصول على رد. المهلة `5` ثوانٍ ثابتة. يتطلّب سماح الشبكة بالاتصال TCP الخارج للمنفذ المستهدف. كل شيء محلي دون خادم وسيط، لكن الاتصال مرئي في سجلّات الهدف — استخدمه فقط على الأنظمة المصرّح لك بها.

**English:** Services that do not auto-announce a banner (many HTTP servers) require a probe line to elicit a reply. The `5`-second timeout is fixed. Requires the network to allow outbound TCP to the target port. Everything is local with no intermediary server, but the connection is visible in the target's logs — only use it on systems you are authorized to test.
