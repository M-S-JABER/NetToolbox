# Redis Client · عميل Redis

> **Category / التصنيف:** Professional / احترافي  
> **Tool ID:** `redis`

---

## نظرة عامة · Overview
**بالعربي:** أداة تتصل بخادم Redis وترسل أمرًا واحدًا وتعرض الردّ منسّقًا. مفيدة لفحص خوادم Redis، والتحقق من الاتصال والمصادقة، وقراءة القيم بسرعة. تفهم بروتوكول RESP (بروتوكول تسلسل Redis) وتنسّق أنواعه المختلفة. التنفيذ أصلي بالكامل بدون مكتبات خارجية.

**English:** A tool that connects to a Redis server, sends a single command, and displays the reply formatted. Useful for probing Redis servers, verifying connectivity and auth, and reading values quickly. It understands the RESP (REdis Serialization Protocol) and formats its various types. Fully native implementation with no external libraries.

## كيف تعمل · How it works
**بالعربي:** الأداة تفتح اتصال TCP (أو TLS إن فُعّل) إلى المنفذ `6379` افتراضيًا. إن أُدخِلت كلمة مرور، تُرسَل أولًا `AUTH <password>` ويُقرأ ردّها. ثم يُرسَل أمرك النصّي كما هو، متبوعًا بـ `\r\n` (صيغة الأوامر المضمَّنة inline). يُقرأ الردّ ويُحلَّل وفق RESP: السلاسل البسيطة (`+`)، والأخطاء (`-`)، والأعداد الصحيحة (`:`)، والسلاسل الكتلية (`$`)، والمصفوفات (`*`) مع التداخل. يُنسَّق الناتج بمسافات بادئة تعكس بنية المصفوفات، مع تحديد التداخل لتفادي تجاوز المكدّس (حتى عمق 32).

**English:** The tool opens a TCP connection (or TLS if enabled) to port `6379` by default. If a password is entered, it first sends `AUTH <password>` and reads the reply. Then it sends your command text as-is, followed by `\r\n` (inline command form). The reply is read and parsed per RESP: simple strings (`+`), errors (`-`), integers (`:`), bulk strings (`$`), and arrays (`*`) with nesting. The output is formatted with indentation reflecting array structure, with a nesting cap to avoid stack overflow (up to depth 32).

## المدخلات · Inputs
- **Host / المضيف:** عنوان خادم Redis · the Redis server address.
- **Port / المنفذ:** الافتراضي `6379` · Defaults to `6379`.
- **TLS / التشفير:** مفتاح لتفعيل الاتصال المشفّر (لخوادم مثل Redis عبر TLS) · toggle for an encrypted connection.
- **Password / كلمة المرور:** اختيارية؛ تُرسَل عبر `AUTH` قبل الأمر · optional; sent via `AUTH` before the command.
- **Command / الأمر:** أمر Redis نصّي، الافتراضي `PING` · a Redis command, default `PING`.

## المخرجات · Outputs
**بالعربي:** بطاقة "الردّ" تعرض الناتج المنسّق. مثلًا `PING` يعيد `PONG`، والعدد الصحيح يظهر كـ `(integer) 42`، والقيمة النصّية بين علامتي اقتباس `"value"`، والقيمة المفقودة `(nil)`، والمصفوفة `(array of N)` متبوعة بعناصرها المُزاحة. الأخطاء من الخادم تظهر بصيغة `(error) …`. يوجد زر نسخ للناتج.

**English:** A "reply" card showing the formatted output. For example `PING` returns `PONG`, an integer shows as `(integer) 42`, a string value is quoted as `"value"`, a missing value as `(nil)`, and an array as `(array of N)` followed by its indented elements. Server-side errors appear as `(error) …`. A copy button is provided.

## مثال تشغيل · Worked example
**بالعربي:** المضيف `127.0.0.1`، المنفذ `6379`، الأمر `INFO server`. المتوقّع: كتلة نصّية بمعلومات الخادم مثل `redis_version:7.2.4` و `os:Linux`. أو الأمر `PING` الذي يعيد `PONG` مباشرة.

**English:** Host `127.0.0.1`, port `6379`, command `INFO server`. Expected: a text block of server info like `redis_version:7.2.4` and `os:Linux`. Or the command `PING` which returns `PONG` directly.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** الأداة ترسل أمرًا واحدًا لكل تشغيل ثم تغلق الاتصال (لا جلسة مستمرّة). بدون TLS يُرسَل الأمر وكلمة المرور بوضوح — فعّل TLS للخوادم البعيدة أو الحسّاسة. تُستخدَم صيغة الأوامر المضمَّنة (inline) لا مصفوفات RESP، فقد لا تعمل مع وسائط تحوي مسافات معقّدة أو بايتات ثنائية. مهلة القراءة `3` ثوانٍ. لا تُخزَّن كلمة المرور خارج الجهاز.

**English:** The tool sends one command per run then closes the connection (no persistent session). Without TLS the command and password are sent in the clear — enable TLS for remote or sensitive servers. It uses inline command form, not RESP arrays, so it may not work with arguments containing complex spaces or binary bytes. The read timeout is `3` seconds. The password is not stored off-device.
