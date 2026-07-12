# DNS-over-HTTPS (DoH) · استعلام DNS المشفّر

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `doh`

---

## نظرة عامة · Overview
**بالعربي:** أداة تُنفّذ استعلام DNS مشفّرًا عبر HTTPS وفق معيار RFC 8484. ترسل استعلام DNS بصيغة wire-format داخل طلب `POST` مشفّر إلى مُحلِّل DoH عام، وتفكّ الرد بنفس مُرمِّز `DNSMessage`. يمنع هذا التنصّت أو التلاعب بالاستعلامات على الشبكة.

**English:** Performs an encrypted DNS query over HTTPS per RFC 8484. It sends a wire-format DNS query inside an encrypted `POST` request to a public DoH resolver and decodes the reply with the same `DNSMessage` codec. This prevents on-path snooping or tampering with queries.

## كيف تعمل · How it works
**بالعربي:** يُرمَّز الاستعلام عبر `DNSMessage.encodeQuery` (معرّف `0`) ثم يُرسَل بطلب `POST` إلى `https://<server>/dns-query` مع الترويسات `content-type: application/dns-message` و`accept: application/dns-message`، ومهلة `10` ثوانٍ، عبر `URLSession` بإعداد `ephemeral`. المنفذ الفعلي هو `443` (HTTPS). يُفكَّك جسم الرد الثنائي بـ `DNSMessage.decodeAnswers`. الخادم الافتراضي هو `cloudflare-dns.com`؛ يمكن استخدام مُحلِّلات أخرى مثل `dns.google` أو `dns.quad9.net`.

**English:** The query is encoded via `DNSMessage.encodeQuery` (ID `0`) and sent as a `POST` to `https://<server>/dns-query` with headers `content-type: application/dns-message` and `accept: application/dns-message`, a `10`-second timeout, over an `ephemeral` `URLSession`. The effective port is `443` (HTTPS). The binary response body is parsed by `DNSMessage.decodeAnswers`. The default server is `cloudflare-dns.com`; other resolvers such as `dns.google` or `dns.quad9.net` also work.

## المدخلات · Inputs
- **Name / الاسم:** اسم النطاق، مثل `example.com` · the domain name.
- **Type / النوع:** نوع السجل من: `A`, `NS`, `CNAME`, `SOA`, `PTR`, `MX`, `TXT`, `AAAA`.
- **Server / الخادم:** اسم مضيف مُحلِّل DoH (بدون البادئة)، الافتراضي `cloudflare-dns.com` · DoH resolver hostname (default `cloudflare-dns.com`).

## المخرجات · Outputs
**بالعربي:** قائمة سجلات الإجابة؛ كل صف يبيّن نوع السجل وقيمته القابلة للنسخ. عند عدم وجود سجلات أو حدوث خطأ (مثل حالة HTTP غير ناجحة) تظهر رسالة مناسبة.

**English:** A list of answer records; each row shows the record type and its copyable value. If there are no records or an error occurs (e.g. a non-2xx HTTP status), a suitable message is shown.

## مثال تشغيل · Worked example
**بالعربي:** الاسم `cloudflare.com`، النوع `AAAA`، الخادم `cloudflare-dns.com`. الناتج المتوقّع: سجلات `AAAA` بقيم IPv6 مثل `2606:4700::6810:85e5`.

**English:** Name `cloudflare.com`, type `AAAA`, server `cloudflare-dns.com`. Expected output: `AAAA` records with IPv6 values like `2606:4700::6810:85e5`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** يتطلّب اتصالاً بالإنترنت؛ عند انقطاع الشبكة تظهر حالة `offline`. يمرّ الاستعلام عبر مُحلِّل خارجي (مثل Cloudflare/Google/Quad9) يرى الاسم المطلوب رغم أن النقل مشفّر. المنفذ `443` نادرًا ما يُحجَب، ما يجعل DoH بديلاً عمليًا حين يُحجَب DNS التقليدي على المنفذ `53`.

**English:** Requires an internet connection; a network outage surfaces an `offline` state. The query passes through an external resolver (e.g. Cloudflare/Google/Quad9) that sees the requested name even though transport is encrypted. Port `443` is rarely blocked, making DoH a practical fallback when classic DNS on port `53` is filtered.
