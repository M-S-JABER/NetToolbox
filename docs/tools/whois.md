# WHOIS · استعلام WHOIS

> **Category / التصنيف:** DNS & Domains / DNS والنطاقات  
> **Tool ID:** `whois`

---

## نظرة عامة · Overview
**بالعربي:** أداة تُنفّذ استعلام WHOIS الكلاسيكي للحصول على بيانات تسجيل نطاق: المُسجِّل، وتواريخ الإنشاء والتحديث والانتهاء، وخوادم الأسماء. تتصل مباشرة بخادم WHOIS عبر TCP على المنفذ `43` وتعرض النص الخام مع ملخّص محلّل للحقول المهمّة.

**English:** Performs a classic WHOIS query to obtain a domain's registration data: registrar, creation/updated/expiry dates, and name servers. It connects directly to a WHOIS server over TCP on port `43` and displays the raw text plus a parsed summary of key fields.

## كيف تعمل · How it works
**بالعربي:** تختار الأداة خادم WHOIS حسب امتداد النطاق (TLD): `com`/`net` ← `whois.verisign-grs.com`، `org` ← `whois.pir.org`، `io` ← `whois.nic.io`، `dev`/`app`/`page` ← `whois.nic.google`، `sa` ← `whois.nic.net.sa`، `uk`/`co` ← `whois.nic.uk`، وأي امتداد آخر ← `whois.iana.org` (الذي يعيد إحالة إلى الخادم المخوّل). تفتح `TCPConnection` نحو `server:43` بمهلة `8` ثوانٍ، وترسل اسم النطاق متبوعًا بـ `\r\n`، ثم تقرأ كل الرد النصّي عبر `receiveAll`. يستخرج `WhoisParser` بعد ذلك الحقول المنظّمة من النص.

**English:** The tool selects a WHOIS server by the domain's TLD: `com`/`net` → `whois.verisign-grs.com`, `org` → `whois.pir.org`, `io` → `whois.nic.io`, `dev`/`app`/`page` → `whois.nic.google`, `sa` → `whois.nic.net.sa`, `uk`/`co` → `whois.nic.uk`, and any other TLD → `whois.iana.org` (which returns a referral to the authoritative server). It opens a `TCPConnection` to `server:43` with an `8`-second timeout, sends the domain name followed by `\r\n`, then reads the entire text response via `receiveAll`. `WhoisParser` then extracts structured fields from the text.

## المدخلات · Inputs
- **Domain / النطاق:** اسم النطاق للاستعلام عنه، مثل `example.com` · the domain name to query.

## المخرجات · Outputs
**بالعربي:** بطاقة ملخّص (عند توفّر الحقول) تعرض المُسجِّل، وتاريخ الإنشاء، وتاريخ التحديث، وتاريخ الانتهاء، وخوادم الأسماء. تليها بطاقة بالنص الخام الكامل لاستجابة WHOIS (قابل للتحديد). يُحفَظ في السجل أول سطر من الرد كملخّص.

**English:** A summary card (when fields are available) showing the registrar, creation date, updated date, expiry date, and name servers. Below it, a card with the full raw WHOIS response text (selectable). The first line of the response is saved to history as a summary.

## مثال تشغيل · Worked example
**بالعربي:** النطاق `example.com`. يُختار الخادم `whois.verisign-grs.com`، والناتج النموذجي يتضمّن `Registrar: RESERVED-Internet Assigned Numbers Authority`، وتاريخ إنشاء `1995-08-14`، وخوادم أسماء مثل `a.iana-servers.net`.

**English:** Domain `example.com`. The server `whois.verisign-grs.com` is chosen; typical output includes `Registrar: RESERVED-Internet Assigned Numbers Authority`, a creation date of `1995-08-14`, and name servers like `a.iana-servers.net`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** يتطلّب سماح الشبكة بحركة TCP الخارجة على المنفذ `43`، وهو منفذ قد تحجبه بعض الشبكات الخلوية أو المؤسسية. اختيار الخادم يعتمد على قائمة TLD ثابتة؛ الامتدادات غير المدرجة تمرّ عبر IANA وقد لا تعطي تفاصيل كاملة دون متابعة الإحالة يدويًا. كثير من السجلات تُخفي بيانات المالك لأسباب الخصوصية (GDPR). لبيانات أحدث ومنظّمة أكثر استخدم أداة RDAP.

**English:** Requires the network to allow outbound TCP on port `43`, which some cellular or corporate networks block. Server selection uses a fixed TLD list; unlisted TLDs go through IANA and may not give full details without manually following the referral. Many registries redact owner data for privacy (GDPR). For fresher, more structured data, use the RDAP tool.
