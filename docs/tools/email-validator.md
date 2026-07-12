# Email Validator · مُدقّق البريد الإلكتروني

> **Category / التصنيف:** Security / الأمان  
> **Tool ID:** `email-validator`

---

## نظرة عامة · Overview
**بالعربي:** مُدقّق البريد الإلكتروني يتحقق من صحة صيغة العنوان ثم يستعلم عن سجلات MX لنطاقه ليقدّر ما إذا كان قابلًا للتسليم. التحقق النصي محلي بحت، ويُضاف إليه استعلام DNS حقيقي لسجلات MX.
**English:** The Email Validator checks the syntax of an address, then queries the MX records of its domain to estimate whether it is deliverable. The syntax check is purely local, layered with a real DNS query for the MX records.

## كيف تعمل · How it works
**بالعربي:** أولًا يطبّق `EmailValidator.isValidSyntax` فحصًا مبسّطًا لـ RFC 5322: يجب وجود `@` واحدة تفصل جزءًا محليًا غير فارغ عن نطاق غير فارغ يحتوي نقطة (ولا يبدأ/ينتهي بها)، وأن تكون الأحرف مسموحة (`._%+-` في الجزء المحلي، `.-` في النطاق) بلا مسافات. إن صحّت الصيغة، يُستخرج النطاق ويُرسَل استعلام DNS من نوع `MX` عبر `UDPDNSResolver` إلى الخادم `1.1.1.1` على المنفذ `53` (UDP)، باستخدام مُرمِّز/مفكِّك `DNSMessage` الداخلي. يُعتبر العنوان «قابلًا للتسليم» إذا كانت الصيغة صحيحة وعاد سجل MX واحد على الأقل.
**English:** First `EmailValidator.isValidSyntax` applies a pragmatic RFC 5322-lite check: there must be exactly one `@` separating a non-empty local part from a non-empty domain that contains a dot (and neither starts nor ends with one), with only allowed characters (`._%+-` in the local part, `.-` in the domain) and no spaces. If the syntax is valid, the domain is extracted and an `MX` DNS query is sent via `UDPDNSResolver` to server `1.1.1.1` on port `53` (UDP), using the internal `DNSMessage` encoder/decoder. The address is considered "deliverable" if the syntax is valid and at least one MX record is returned.

## المدخلات · Inputs
- **Email / البريد الإلكتروني:** عنوان بريد كامل (مثل `user@example.com`). / A full email address.

## المخرجات · Outputs
**بالعربي:** بطاقة **الملخّص**: بشارة صحة الصيغة (خضراء/حمراء)، وبشارة القابلية للتسليم (`deliverable` خضراء أو `no MX` برتقالية). وإذا وُجدت سجلات MX تظهر بطاقة تسردها (كل سجل قابل للنسخ).
**English:** A **Summary** card: a syntax-validity badge (green/red) and a deliverability badge (`deliverable` green or `no MX` orange). If MX records exist, a card lists them (each copyable).

## مثال تشغيل · Worked example
**بالعربي:** المدخل `user@gmail.com`. النتيجة: الصيغة صحيحة، والاستعلام إلى `1.1.1.1` يعيد سجلات MX مثل `gmail-smtp-in.l.google.com`، فتظهر البشارة `deliverable`. أما `user@b` فترفض لغياب TLD.
**English:** Input `user@gmail.com`. Result: syntax valid, and the query to `1.1.1.1` returns MX records such as `gmail-smtp-in.l.google.com`, showing a `deliverable` badge. In contrast `user@b` is rejected for lacking a TLD.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** وجود سجل MX لا يضمن أن صندوق المستخدم نفسه موجود؛ إنه مؤشّر على قابلية النطاق لاستقبال البريد فقط. يعتمد الاستعلام على المُحلِّل `1.1.1.1` (Cloudflare) عبر UDP، وقد تحجب بعض الشبكات المنفذ `53`. لا يتطلب أذونات خاصة على iOS.
**English:** The presence of an MX record does not guarantee the specific mailbox exists; it only indicates the domain can receive mail. The query relies on the `1.1.1.1` (Cloudflare) resolver over UDP, and some networks block port `53`. No special iOS permissions are required.
