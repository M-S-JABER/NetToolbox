# RPKI Validation · التحقق من RPKI

> **Category / التصنيف:** BGP / التوجيه العالمي (BGP)  
> **Tool ID:** `rpki`

---

## نظرة عامة · Overview
**بالعربي:** أداة تتحقق من صلاحية إعلان مسار BGP وفق RPKI (البنية العامة لموارد الإنترنت)، بإدخال رقم نظام ذاتي وبادئة، فتُظهر ما إذا كان الزوج صالحاً (valid) أو غير صالح (invalid) أو غير معروف (unknown)، مع شهادات المسار (ROAs) المطابِقة. تعتمد على واجهة بيانات **RIPEstat** على `stat.ripe.net`.
**English:** Validates a BGP route announcement against RPKI (Resource Public Key Infrastructure). Given an AS number and a prefix, it shows whether the pair is valid, invalid, or unknown, along with the matching Route Origin Authorizations (ROAs). It uses the **RIPEstat** data API at `stat.ripe.net`.

## كيف تعمل · How it works
**بالعربي:** تُطبَّع قيمة ASN إلى أرقام فقط (تقبل `AS13335` أو `as 13335` أو `13335`)، ثم تُبنى نقطة النهاية `https://stat.ripe.net/data/rpki-validation/data.json?resource=<asn>&prefix=<prefix>` وتُطلَب عبر HTTPS باستخدام جلسة `URLSession` عابرة (ephemeral، بلا تخزين مؤقت). يُفكّ رد JSON: الحقل `status` يُطبَّع (`valid`، أو `invalid`/`invalid_asn`/`invalid_length` → غير صالح، وغير ذلك → غير معروف)، ويُقرأ مصفوف `validating_roas` لعرض كل شهادة ROA بأصلها وبادئتها وطولها الأقصى وصلاحيتها.
**English:** The ASN is normalized to digits only (accepts `AS13335`, `as 13335`, or `13335`), then the endpoint `https://stat.ripe.net/data/rpki-validation/data.json?resource=<asn>&prefix=<prefix>` is built and requested over HTTPS using an ephemeral `URLSession` (no caching). The JSON reply is decoded: the `status` field is normalized (`valid`; `invalid`/`invalid_asn`/`invalid_length` → invalid; anything else → unknown), and the `validating_roas` array is read to display each ROA with its origin, prefix, max-length, and validity.

## المدخلات · Inputs
- **رقم النظام الذاتي / ASN:** بأي صيغة مثل `AS13335` · The AS number in any form, e.g. `AS13335`.
- **البادئة / Prefix:** البادئة المُعلَنة مثل `1.1.1.0/24` · The announced prefix, e.g. `1.1.1.0/24`.

## المخرجات · Outputs
**بالعربي:** شارة حالة ملوّنة: أخضر (valid)، أحمر (invalid)، أصفر (unknown)، مع سطر `AS… · البادئة`. ثم قائمة شهادات ROA المطابِقة، كل منها بصيغة `AS<الأصل> → <البادئة>` وسطر `max-length /<الطول> · <الصلاحية>`. إن لم توجد شهادات تظهر رسالة "لا ROAs".
**English:** A colored status badge: green (valid), red (invalid), yellow (unknown), with an `AS… · prefix` line. Then the list of matching ROAs, each as `AS<origin> → <prefix>` and a `max-length /<length> · <validity>` line. If none exist, a "no ROAs" message is shown.

## مثال تشغيل · Worked example
**بالعربي:** الإدخال: ASN `AS13335`، البادئة `1.1.1.0/24`. النتيجة: شارة خضراء **valid**، وشهادة ROA: `AS13335 → 1.1.1.0/24`، `max-length /24 · valid`.
**English:** Input: ASN `AS13335`, prefix `1.1.1.0/24`. Result: a green **valid** badge, with a ROA: `AS13335 → 1.1.1.0/24`, `max-length /24 · valid`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** تتطلب اتصال إنترنت للوصول إلى `stat.ripe.net`. النتيجة تعكس حالة التحقق من RPKI كما تراها RIPEstat في لحظة الاستعلام. حالة "غير معروف" تعني غياب شهادة ROA مغطّية وليست خطأً. يجب إدخال ASN والبادئة معاً وإلا يظهر خطأ مُدخَل. تُستخدم جلسة عابرة بلا تخزين مؤقت لضمان نتيجة حديثة.
**English:** Requires internet access to reach `stat.ripe.net`. The result reflects the RPKI validation state as RIPEstat sees it at query time. An "unknown" status means no covering ROA exists and is not an error. Both the ASN and prefix must be supplied or an input error is shown. An ephemeral, non-caching session is used to ensure a fresh result.
