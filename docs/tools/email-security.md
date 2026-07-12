# Email Security · فحص أمان البريد الإلكتروني

> **Category / التصنيف:** Security / الأمان  
> **Tool ID:** `email-security`

---

## نظرة عامة · Overview
**بالعربي:** أداة تفحص سجلات مصادقة البريد الإلكتروني لنطاق ما: SPF وDMARC وDKIM. تكشف ما إذا كان النطاق محميًا ضد انتحال البريد، عبر البحث في سجلات DNS من نوع TXT باستخدام DNS-over-HTTPS.

**English:** Checks a domain's email-authentication records: SPF, DMARC, and DKIM. It reveals whether the domain is protected against email spoofing by looking up TXT DNS records using DNS-over-HTTPS.

## كيف تعمل · How it works
**بالعربي:** تعيد الأداة استخدام `DoHResolver` لتنفيذ ثلاثة استعلامات TXT مشفّرة (RFC 8484، `POST` إلى `https://cloudflare-dns.com/dns-query` على المنفذ `443`):
- **SPF:** استعلام TXT على النطاق نفسه، والبحث عن قيمة تحوي `v=spf1`.
- **DMARC:** استعلام TXT على `_dmarc.<domain>`، والبحث عن `v=dmarc1`.
- **DKIM:** استعلام TXT على `<selector>._domainkey.<domain>`، والبحث عن `p=`.
تُزال علامات الاقتباس من القيم، وتُعاد أول قيمة تطابق النص المطلوب (بحث غير حسّاس لحالة الأحرف).

**English:** The tool reuses `DoHResolver` to run three encrypted TXT queries (RFC 8484, `POST` to `https://cloudflare-dns.com/dns-query` on port `443`):
- **SPF:** TXT query on the domain itself, looking for a value containing `v=spf1`.
- **DMARC:** TXT query on `_dmarc.<domain>`, looking for `v=dmarc1`.
- **DKIM:** TXT query on `<selector>._domainkey.<domain>`, looking for `p=`.
Quotes are stripped from values, and the first value matching the needle is returned (case-insensitive).

## المدخلات · Inputs
- **Domain / النطاق:** اسم النطاق، مثل `example.com` (يُحوَّل لأحرف صغيرة) · the domain name (lowercased).
- **Selector / المُحدِّد:** مُحدِّد DKIM، الافتراضي `default` · the DKIM selector (default `default`). محدِّدات شائعة أخرى: `google`, `s1`, `selector1`.

## المخرجات · Outputs
**بالعربي:** ثلاث بطاقات (SPF, DMARC, DKIM) لكلٍّ منها شارة `present`/`absent`، والقيمة الكاملة للسجل عند وجوده (قابلة للتحديد)، وتلميح يشرح الغرض من كل سجل. عند فشل الاستعلام تظهر رسالة خطأ.

**English:** Three cards (SPF, DMARC, DKIM), each with a `present`/`absent` badge, the full record value when found (selectable), and a hint explaining each record's purpose. On query failure, an error message is shown.

## مثال تشغيل · Worked example
**بالعربي:** النطاق `google.com`، المُحدِّد `google`. الناتج النموذجي: SPF = `present` بقيمة مثل `v=spf1 include:_spf.google.com ~all`؛ DMARC = `present` بقيمة `v=DMARC1; p=reject; ...`؛ DKIM = `present` بمفتاح عام يبدأ بـ `v=DKIM1; k=rsa; p=...`.

**English:** Domain `google.com`, selector `google`. Typical output: SPF = `present` with a value like `v=spf1 include:_spf.google.com ~all`; DMARC = `present` with `v=DMARC1; p=reject; ...`; DKIM = `present` with a public key beginning `v=DKIM1; k=rsa; p=...`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** فحص DKIM يعتمد على مُحدِّد واحد فقط؛ إن كان النطاق يستخدم مُحدِّدًا مختلفًا سيظهر «مفقود» رغم وجود DKIM فعليًا — جرّب مُحدِّدات شائعة. تعتمد الأداة على مُحلِّل Cloudflare الثابت وتتطلّب اتصالاً بالإنترنت. لا تتحقّق الأداة من صحّة صياغة السجلات أو صلاحيتها، بل من وجودها فقط.

**English:** The DKIM check uses a single selector; if the domain uses a different one, it shows "absent" even though DKIM exists — try common selectors. The tool relies on the fixed Cloudflare resolver and requires an internet connection. It only checks for record presence, not for correct syntax or validity.
