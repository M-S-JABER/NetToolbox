# Port Scanner · فاحص المنافذ

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `port-scanner`

---

## نظرة عامة · Overview
**بالعربي:** أداة محلية بالكامل تفحص منافذ TCP على مضيف معيّن لمعرفة أيّها مفتوح. تعتمد على محاولة إتمام مصافحة TCP (اتصال حقيقي) لكل منفذ عبر إطار عمل `Network` في نظام iOS، دون إرسال أي بيانات إلى خدمة خارجية.

**English:** A fully local tool that scans TCP ports on a target host to see which are open. It works by attempting a real TCP handshake to each port using the iOS `Network` framework — no data is sent to any external service.

## كيف تعمل · How it works
**بالعربي:** لكل منفذ في القائمة، تُنشئ الأداة اتصال `NWConnection` من نوع `.tcp` نحو المضيف والمنفذ. إذا وصلت الحالة إلى `.ready` فالمنفذ مفتوح؛ وإذا كانت `.failed` أو `.waiting` (رفض/غير قابل للوصول) فالمنفذ مُغلق. الفحص يجري بتوازٍ محدود عبر `ConcurrencyLimiter` (حتى 24 منفذًا في آن واحد) مع مهلة `1.5` ثانية لكل منفذ. أسماء الخدمات تُستخرج محليًا من `PortDatabase.serviceName`. لا يوجد فحص UDP ولا إرسال حِزم خام — مجرد محاولة اتصال TCP قياسية.

**English:** For each port in the list, the tool opens an `NWConnection` of type `.tcp` to the host and port. Reaching state `.ready` means the port is open; `.failed` or `.waiting` (refused/unreachable) means closed. Scanning runs with bounded concurrency via `ConcurrencyLimiter` (up to 24 ports at once) with a `1.5` second timeout per port. Service names are resolved locally from `PortDatabase.serviceName`. There is no UDP scan and no raw-packet crafting — just a standard TCP connect attempt.

## المدخلات · Inputs
- **Host / المضيف:** اسم نطاق أو عنوان IP للهدف · Hostname or IP address of the target.
- **Preset / النمط الجاهز:** أحد الخيارات · one of:
  - `common` — منافذ شائعة مثل `21, 22, 23, 25, 53, 80, 110, 139, 143, 443, 445, 587, 993, 995, 3306, 3389, 5432, 8080, 8443, 8728`.
  - `web` — منافذ الويب: `80, 443, 8000, 8008, 8080, 8443, 8888`.
  - `all` — كل المنافذ المعرّفة في `PortDatabase`.
  - `custom` — قائمة يدوية.
- **Custom ports / منافذ مخصّصة:** نص مثل `1-1024, 8080, 3000-3010`؛ يُحلَّل عبر `PortList.parse` ويقبل نطاقات وأرقامًا مفصولة بفواصل/مسافات، بحد أقصى `4096` منفذًا، وأرقام ضمن `1…65535`.

## المخرجات · Outputs
**بالعربي:** شريط تقدّم يوضح `scanned / total`، وشارة تعرض عدد المنافذ المفتوحة، وقائمة بكل منفذ مفتوح مع رقمه واسم الخدمة المتوقّعة (مثل `22 → ssh`). تُحفَظ آخر 10 عمليات في السجل بصيغة `host — N open / total`.

**English:** A progress bar showing `scanned / total`, a badge with the open-port count, and a list of each open port with its number and expected service name (e.g. `22 → ssh`). The last 10 runs are stored in history as `host — N open / total`.

## مثال تشغيل · Worked example
**بالعربي:** إدخال المضيف `scanme.nmap.org` مع النمط `common`. النتيجة النموذجية: `22 ssh` و`80 http` مفتوحان، والبقية مغلقة، مع شارة `2 open`.

**English:** Enter host `scanme.nmap.org` with preset `common`. Typical result: `22 ssh` and `80 http` shown as open, the rest closed, with a `2 open` badge.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** الفحص TCP-connect فقط (لا يوجد SYN خفي ولا UDP)، لذا قد يظهر بوضوح في سجلّات الهدف. النتائج تعتمد على جدران الحماية والشبكة الوسيطة؛ قد يظهر منفذ «مغلق» بسبب حظر لا بسبب عدم وجود خدمة. لا تُرسَل بيانات لأي خادم خارجي — كل شيء محلي على الجهاز. افحص فقط الأنظمة المصرّح لك بفحصها.

**English:** This is TCP-connect scanning only (no stealth SYN, no UDP), so it is visible in the target's logs. Results depend on firewalls and intermediate networks; a port may read "closed" due to filtering rather than an absent service. No data leaves the device — everything runs locally. Only scan systems you are authorized to test.
