# Certificate Transparency · شفافية الشهادات

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `cert-transparency`

---

## نظرة عامة · Overview
**بالعربي:** أداة تبحث في سجلات شفافية الشهادات (Certificate Transparency) عن كل شهادة TLS صُدرت علنًا لنطاق معيّن. مفيدة لاكتشاف الشهادات المنسيّة أو المارقة والنطاقات الفرعية المخفيّة، عبر خدمة `crt.sh` المجانية دون الحاجة لأي مفتاح.

**English:** Searches Certificate Transparency logs for every TLS certificate ever publicly issued for a domain. Useful for spotting forgotten or rogue certificates and hidden subdomains, via the free `crt.sh` service with no API key required.

## كيف تعمل · How it works
**بالعربي:** تُرسِل الأداة طلب `GET` إلى `https://crt.sh/?q=<domain>&output=json` (المنفذ `443`) بمهلة `20` ثانية عبر `URLSession` بإعداد `ephemeral`. تُفكَّك استجابة JSON إلى صفوف تحوي المعرّف والاسم الشائع (CN) وقائمة الأسماء (SAN) واسم المُصدِر وتاريخي البداية والنهاية. تُزال التكرارات بمفتاح مركّب (`common_name|not_after|issuer`)، ويُختصر اسم المُصدِر إلى الجزء `CN=` منه، وتُقتطع التواريخ إلى صيغة اليوم. يُعرَض حتى `50` إدخالًا كحد أقصى.

**English:** The tool sends a `GET` request to `https://crt.sh/?q=<domain>&output=json` (port `443`) with a `20`-second timeout over an `ephemeral` `URLSession`. The JSON response is decoded into rows containing the id, common name (CN), name list (SAN), issuer name, and not-before/not-after dates. Duplicates are removed by a composite key (`common_name|not_after|issuer`), the issuer name is shortened to its `CN=` part, and dates are truncated to day format. Up to `50` entries are shown.

## المدخلات · Inputs
- **Domain / النطاق:** اسم النطاق للبحث عنه، مثل `example.com` (يُحوَّل لأحرف صغيرة). يمكن استخدام رموز البدل مثل `%.example.com` للنطاقات الفرعية · the domain to search (lowercased); wildcards like `%.example.com` work for subdomains.

## المخرجات · Outputs
**بالعربي:** قائمة إدخالات الشهادات؛ كل إدخال يعرض الاسم الشائع، ثم سطرًا بالمُصدِر ونطاق الصلاحية (`البداية → النهاية`)، وإذا تضمّنت الشهادة أكثر من اسم تُعرَض أول 8 أسماء من قائمة SAN. عند غياب النتائج تظهر رسالة «فارغ».

**English:** A list of certificate entries; each shows the common name, then a line with the issuer and validity range (`not_before → not_after`), and if the certificate covers more than one name, the first 8 SAN names are shown. If there are no results, an "empty" message appears.

## مثال تشغيل · Worked example
**بالعربي:** النطاق `github.com`. الناتج النموذجي: عدة إدخالات مثل الاسم الشائع `github.com`، المُصدِر `Sectigo ECC Domain Validation Secure Server CA`، النطاق `2023-02-14 → 2024-03-14`، وقائمة أسماء تشمل `www.github.com`.

**English:** Domain `github.com`. Typical output: several entries such as common name `github.com`, issuer `Sectigo ECC Domain Validation Secure Server CA`, range `2023-02-14 → 2024-03-14`, and a name list including `www.github.com`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** يتطلّب اتصالاً بالإنترنت، وخدمة `crt.sh` قد تكون بطيئة أو غير متاحة أحيانًا (لذا مهلة `20` ثانية). النتائج مقتصرة على `50` إدخالًا فريدًا؛ النطاقات الكبيرة قد يكون لها المزيد. البيانات تاريخية من السجلات العامة وقد تتضمّن شهادات منتهية أو مُلغاة. لا يُرسَل أي مفتاح أو بيانات اعتماد.

**English:** Requires an internet connection, and `crt.sh` can be slow or occasionally unavailable (hence the `20`-second timeout). Results are capped at `50` unique entries; large domains may have more. The data is historical from public logs and may include expired or revoked certificates. No API key or credentials are sent.
