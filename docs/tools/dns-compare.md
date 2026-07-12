# DNS Compare · مقارنة مُحلِّلات DNS

> **Category / التصنيف:** DNS & Domains / DNS والنطاقات  
> **Tool ID:** `dns-compare`

---

## نظرة عامة · Overview
**بالعربي:** أداة تستعلم عن نفس السجل من عدة مُحلِّلات DNS-over-HTTPS عامة في آنٍ واحد وتقارن إجاباتها. تكشف عن تأخّر انتشار DNS أو عن إجابات متباينة (تصفية/تسميم/حجب جغرافي) بين المزوّدين.

**English:** Queries the same record from several public DNS-over-HTTPS resolvers at once and compares their answers. It reveals DNS propagation lag or divergent responses (filtering/poisoning/geo-blocking) across providers.

## كيف تعمل · How it works
**بالعربي:** تعيد الأداة استخدام `DoHResolver` نفسه لتنفيذ استعلام مشفّر (RFC 8484، طلب `POST` إلى `https://<host>/dns-query` على المنفذ `443`) بالتوازي لكل مُحلِّل. المُحلِّلات الأربعة الثابتة هي: **Cloudflare** (`cloudflare-dns.com`)، **Google** (`dns.google`)، **Quad9** (`dns.quad9.net`)، **AdGuard** (`dns.adguard-dns.com`). تُرشَّح النتائج حسب النوع المطلوب وتُرتَّب القيم، ثم يُحسَب «الاتفاق» بمقارنة مجموعات القيم لكل المُحلِّلات التي أجابت بنجاح.

**English:** The tool reuses the shared `DoHResolver` to run an encrypted query (RFC 8484, `POST` to `https://<host>/dns-query` on port `443`) in parallel against each resolver. The four fixed resolvers are: **Cloudflare** (`cloudflare-dns.com`), **Google** (`dns.google`), **Quad9** (`dns.quad9.net`), **AdGuard** (`dns.adguard-dns.com`). Results are filtered to the requested type and sorted, then an "agreement" flag is computed by comparing the value sets of all resolvers that answered successfully.

## المدخلات · Inputs
- **Name / الاسم:** اسم النطاق للاستعلام عنه، مثل `example.com` · the domain name.
- **Type / النوع:** نوع السجل من: `A`, `NS`, `CNAME`, `SOA`, `PTR`, `MX`, `TXT`, `AAAA`.

## المخرجات · Outputs
**بالعربي:** شارة اتفاق/اختلاف أعلى النتائج (`agree` إذا تطابقت كل الإجابات، وإلا `disagree`)، ثم بطاقة لكل مُحلِّل تعرض اسمه وقيم إجابته أو رسالة الخطأ. يُحسَب الاتفاق فقط عند وجود أكثر من مُحلِّل أجاب بقيم.

**English:** An agree/disagree badge above the results (`agree` if all answers match, otherwise `disagree`), then a card per resolver showing its name and answer values or an error message. Agreement is only computed when more than one resolver answered with values.

## مثال تشغيل · Worked example
**بالعربي:** الاسم `github.com`، النوع `A`. الناتج النموذجي: تُظهر Cloudflare وGoogle وQuad9 وAdGuard نفس العنوان (مثل `140.82.121.4`) مع شارة `agree`. أما نطاق مُصفّى إعلانيًا فقد يُظهر AdGuard قيمة مختلفة (مثل `0.0.0.0`) وتظهر شارة `disagree`.

**English:** Name `github.com`, type `A`. Typical output: Cloudflare, Google, Quad9 and AdGuard all show the same address (e.g. `140.82.121.4`) with an `agree` badge. For an ad-filtered domain, AdGuard may return a different value (e.g. `0.0.0.0`), producing a `disagree` badge.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** يتطلّب اتصالاً بالإنترنت وأربعة استعلامات HTTPS متوازية. الاختلاف لا يعني بالضرورة خللًا؛ قد ينتج عن توازن الأحمال الجغرافي (CDN) أو التصفية المتعمّدة لدى مُحلِّل معيّن. القائمة ثابتة على المُحلِّلات الأربعة ولا يمكن تخصيصها من الواجهة.

**English:** Requires internet and four parallel HTTPS queries. A disagreement is not necessarily a fault; it can arise from geographic load balancing (CDN) or intentional filtering by a given resolver. The resolver list is fixed to these four and is not user-customizable in the UI.
