# Certificate Expiry · انتهاء صلاحية الشهادة

> **Category / التصنيف:** Security / الأمان  
> **Tool ID:** `cert-expiry`

---

## نظرة عامة · Overview
**بالعربي:** أداة انتهاء صلاحية الشهادة تراقب قائمة من المضيفين وتُظهر كم يومًا يتبقّى قبل انتهاء شهادة TLS لكل منهم، مع تصنيف لوني للحالة. تفتح اتصال TLS مباشرًا بالمنفذ `443` وتفحص الشهادة محليًا دون أي خدمة خارجية.
**English:** The Certificate Expiry tool watches a list of hosts and shows how many days remain before each one's TLS certificate expires, with a color-coded status. It opens a direct TLS connection to port `443` and inspects the certificate locally, with no external service.

## كيف تعمل · How it works
**بالعربي:** لكل مضيف تُنشئ الأداة اتصال TLS عبر `NWConnection` (بروتوكول `NWProtocolTLS`) إلى المنفذ `443`. داخل كتلة التحقق (`sec_protocol_options_set_verify_block`) تلتقط سلسلة الشهادات من كائن `SecTrust`، وتستخرج الاسم (subject) والمُصدِر (issuer). بما أن iOS لا يوفّر واجهة لقراءة تواريخ الصلاحية من `SecCertificate`، تُحلَّل تواريخ `notBefore` و`notAfter` من ترميز DER مباشرةً عبر `X509`. تُحسب الأيام المتبقية من `notAfter`. يُصنّف `CertExpiryEngine.level` المدة: أكثر من 30 يومًا = سليم (`ok`)، أقل من 30 = تحذير (`warning`)، أقل من 15 = حرِج (`critical`)، أقل من صفر = منتهية (`expired`). تُنفَّذ فحوص المضيفين بالتوازي.
**English:** For each host the tool establishes a TLS connection via `NWConnection` (`NWProtocolTLS`) to port `443`. Inside the verify block (`sec_protocol_options_set_verify_block`) it captures the certificate chain from the `SecTrust` object and extracts the subject and issuer. Because iOS has no API to read validity dates from a `SecCertificate`, the `notBefore`/`notAfter` dates are parsed directly out of the DER encoding via `X509`. Days remaining are computed from `notAfter`. `CertExpiryEngine.level` buckets the result: more than 30 days = `ok`, under 30 = `warning`, under 15 = `critical`, below zero = `expired`. Host checks run concurrently.

## المدخلات · Inputs
- **Host / المضيف:** اسم النطاق المراد مراقبته (مثل `apple.com`)، ويُضاف إلى القائمة بزر `+`. / Hostname to watch; added to the list with the `+` button.
- **Refresh / تحديث:** يعيد فحص كل المضيفين في القائمة. / Re-checks all hosts in the list.

## المخرجات · Outputs
**بالعربي:** لكل مضيف: اسمه، تاريخ `notAfter`، وبشارة بالأيام المتبقية بلون يعكس الحالة (أخضر/برتقالي/أحمر) أو `expired`. يمكن تصدير القائمة كملف CSV يشمل: `host`، `daysRemaining`، `notAfter`، `subject`، `error`.
**English:** For each host: its name, the `notAfter` date, and a badge of days remaining colored by status (green/orange/red) or `expired`. The list can be exported as CSV with columns: `host`, `daysRemaining`, `notAfter`, `subject`, `error`.

## مثال تشغيل · Worked example
**بالعربي:** إضافة `apple.com`. تتصل الأداة على `443`، وتقرأ `notAfter = 2026-09-20`، فتعرض بشارة مثل `70d` باللون الأخضر (سليم).
**English:** Add `apple.com`. The tool connects on `443`, reads `notAfter = 2026-09-20`, and shows a badge like `70d` in green (healthy).

## ملاحظات وقيود · Notes & limitations
**بالعربي:** الفحص مقصور على المنفذ `443`. الأداة تعرض بيانات الشهادة حتى لو لم يثق بها النظام. تحليل تواريخ DER يعتمد على شهادات X.509 قياسية. الاتصال مباشر من جهازك؛ لا يتطلب أذونات خاصة على iOS.
**English:** Checks are limited to port `443`. The tool reports certificate data even if the system does not trust it. DER date parsing assumes standard X.509 certificates. The connection is direct from your device; no special iOS permissions are required.
