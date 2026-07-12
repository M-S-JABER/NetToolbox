# DNS Health · صحّة DNS

> **Category / التصنيف:** DNS & Domains / DNS والنطاقات  
> **Tool ID:** `dns-health`

---

## نظرة عامة · Overview
**بالعربي:** أداة تفحص «صحّة» نطاق من زاويتين: اتساق الانتشار عبر عدة مُحلِّلات DNS عامة، وحالة توقيع DNSSEC. تستعلم عن نفس السجل من ستة مُحلِّلات مشهورة عبر UDP وتقارن إجاباتها، ثم تتحقّق من التوقيع الأمني للنطاق.

**English:** Checks a domain's "health" from two angles: propagation consistency across several public DNS resolvers, and DNSSEC signing status. It queries the same record from six well-known resolvers over UDP and compares their answers, then verifies the domain's security signature.

## كيف تعمل · How it works
**بالعربي:** **الانتشار:** يستعلم بالتوازي عبر `UDPDNSResolver` (UDP على المنفذ `53`) من ستة مُحلِّلات ثابتة: Cloudflare `1.1.1.1`، Google `8.8.8.8`، Quad9 `9.9.9.9`، OpenDNS `208.67.222.222`، AdGuard `94.140.14.14`، Level3 `4.2.2.2`. يُعتبر النطاق «متّسقًا» إذا أعادت كل المُحلِّلات التي أجابت نفس مجموعة القيم. **DNSSEC:** يبني استعلامًا مع بِت EDNS0 DO مفعّلًا (`dnssecOK: true`) ويرسله إلى `1.1.1.1:53`، ثم يقرأ أعلام الرد عبر `DNSMessage.responseFlags`: بِت `authenticated` (AD) يعني `signed`، وغيابه `unsigned`، ورمز الخطأ `rcode == 2` (SERVFAIL من مُحلِّل مُتحقِّق) يعني `bogus`، وتعذّر الرد يعني `unknown`.

**English:** **Propagation:** queries in parallel via `UDPDNSResolver` (UDP on port `53`) from six fixed resolvers: Cloudflare `1.1.1.1`, Google `8.8.8.8`, Quad9 `9.9.9.9`, OpenDNS `208.67.222.222`, AdGuard `94.140.14.14`, Level3 `4.2.2.2`. The domain is "consistent" if every resolver that answered returned the same value set. **DNSSEC:** builds a query with the EDNS0 DO bit set (`dnssecOK: true`) and sends it to `1.1.1.1:53`, then reads the response flags via `DNSMessage.responseFlags`: the `authenticated` (AD) bit means `signed`, its absence `unsigned`, an `rcode == 2` (SERVFAIL from a validating resolver) means `bogus`, and no reply means `unknown`.

## المدخلات · Inputs
- **Host / المضيف:** اسم النطاق المراد فحصه، مثل `example.com` · the domain to check.
- **Type / النوع:** نوع السجل من: `A`, `NS`, `CNAME`, `SOA`, `PTR`, `MX`, `TXT`, `AAAA`.

## المخرجات · Outputs
**بالعربي:** قسم DNSSEC بشارة (`signed` أخضر / `unsigned` أصفر / `bogus` أحمر / `unknown` محايد). قسم الانتشار بشارة `consistent`/`inconsistent` وصف لكل مُحلِّل من الستة يعرض اسمه وعنوانه وقيمه أو خطأه، مع زر تصدير CSV (الأعمدة: `resolver, server, values, error`).

**English:** A DNSSEC section with a badge (`signed` green / `unsigned` yellow / `bogus` red / `unknown` neutral). A propagation section with a `consistent`/`inconsistent` badge and a row per resolver showing its name, IP, and values or error, plus a CSV export button (columns: `resolver, server, values, error`).

## مثال تشغيل · Worked example
**بالعربي:** المضيف `cloudflare.com`، النوع `A`. النتيجة النموذجية: DNSSEC = `signed`، والانتشار = `consistent` مع إظهار كل المُحلِّلات الستة لنفس العناوين. أما نطاق بلا توقيع فسيظهر `unsigned`.

**English:** Host `cloudflare.com`, type `A`. Typical result: DNSSEC = `signed`, propagation = `consistent` with all six resolvers showing the same addresses. A domain without signing would show `unsigned`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** يعتمد فحص DNSSEC على مُحلِّل واحد مُتحقِّق (`1.1.1.1`) وقراءة بِت AD؛ فهو تحقّق غير مباشر لا يتحقّق من سلسلة التوقيع محليًا. الاتساق قد يتأثّر بتوازن الأحمال الجغرافي (CDN) فيظهر «غير متّسق» رغم سلامة النطاق. يتطلّب سماح الشبكة بحركة UDP على المنفذ `53` لكل المُحلِّلات الستة.

**English:** The DNSSEC check relies on a single validating resolver (`1.1.1.1`) and reading the AD bit; it is an indirect check that does not validate the signature chain locally. Consistency can be affected by geographic load balancing (CDN), showing "inconsistent" even for a healthy domain. Requires the network to allow UDP on port `53` to all six resolvers.
