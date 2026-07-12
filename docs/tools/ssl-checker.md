# SSL/TLS Checker · فاحص SSL/TLS

> **Category / التصنيف:** Security / الأمان  
> **Tool ID:** `ssl-checker`

---

## نظرة عامة · Overview
**بالعربي:** فاحص SSL/TLS يُجري مصافحة TLS مع الخادم، ويفحص شهادته وسلسلة الثقة، ويكتشف إصدارات TLS المدعومة، ثم يمنح درجة أمان تلخّص الحالة. كل ذلك محليًا على الجهاز باستخدام أطر Network وSecurity، دون إرسال البيانات إلى خدمة خارجية مثل SSL Labs.
**English:** The SSL/TLS Checker performs a TLS handshake with the server, inspects its certificate and trust chain, detects supported TLS versions, and assigns a security grade summarizing the result. All of this runs locally on the device using the Network and Security frameworks, without sending data to an external service like SSL Labs.

## كيف تعمل · How it works
**بالعربي:** تفتح الأداة اتصال TLS عبر `NWConnection` إلى المضيف والمنفذ (افتراضيًا `443`). من داخل كتلة التحقق تلتقط سلسلة الشهادات من `SecTrust`: الاسم (subject)، المُصدِر (issuer)، طول السلسلة، وهل يثق بها النظام (`SecTrustEvaluateWithError`). تُحلّل تواريخ `notBefore`/`notAfter` والأسماء البديلة (SAN) من ترميز DER عبر `X509`، ويُقرأ نوع المفتاح وحجمه (`RSA`/`EC`) عبر `SecKeyCopyAttributes`. بالتوازي تفحص الأداة إصدارات `TLS 1.0`–`1.3` بفتح اتصال منفصل لكل إصدار (بتثبيت الحد الأدنى والأعلى للنسخة) واعتبار النسخة مدعومة إذا اكتملت المصافحة. ثم يطبّق `TLSAudit.grade` قواعد استدلالية للدرجة: منتهية = `F`، لا يوجد بروتوكول حديث = `F`، مفتاح ضعيف = `F`، غير موثوق = `T`، وجود بروتوكول قديم (1.0/1.1) يخفّض إلى `C`، ودعم `TLS 1.3` مع شهادة قوية موثوقة يرفع إلى `A+`.
**English:** The tool opens a TLS connection via `NWConnection` to the host and port (default `443`). From the verify block it captures the certificate chain from `SecTrust`: subject, issuer, chain length, and whether the system trusts it (`SecTrustEvaluateWithError`). The `notBefore`/`notAfter` dates and Subject Alternative Names (SANs) are parsed from the DER via `X509`, and the key type and size (`RSA`/`EC`) are read via `SecKeyCopyAttributes`. In parallel it probes `TLS 1.0`–`1.3` by opening a separate connection per version (pinning both min and max version) and treating a version as supported if the handshake completes. `TLSAudit.grade` then applies heuristics: expired = `F`, no modern protocol = `F`, weak key = `F`, untrusted = `T`, presence of legacy 1.0/1.1 downgrades to `C`, and `TLS 1.3` with a strong, trusted certificate raises to `A+`.

## المدخلات · Inputs
- **Host / المضيف:** اسم النطاق المراد فحصه (مثل `apple.com`). / Hostname to check.
- **Port / المنفذ:** منفذ TLS (افتراضيًا `443`). / TLS port (defaults to `443`).

## المخرجات · Outputs
**بالعربي:** بطاقة **الدرجة** (`A+`..`F` أو `T` لغير الموثوق) مع قائمة البروتوكولات المدعومة وملاحظات (قديم، مفتاح ضعيف، قرب انتهاء…). وبطاقة **الشهادة**: حالة الثقة، الأيام المتبقية، الاسم، المُصدِر، `notBefore`/`notAfter`، طول السلسلة، نوع وحجم المفتاح، والأسماء البديلة (SAN).
**English:** A **Grade** card (`A+`..`F`, or `T` for untrusted) with the list of supported protocols and notes (legacy, weak key, expiring…). A **Certificate** card: trust status, days remaining, subject, issuer, `notBefore`/`notAfter`, chain length, key type and size, and SANs.

## مثال تشغيل · Worked example
**بالعربي:** المدخل `apple.com` على المنفذ `443`. النتيجة: الدرجة `A+`، البروتوكولات `TLS 1.2 · TLS 1.3`، الشهادة موثوقة، الأيام المتبقية `70d`، المفتاح `EC 256-bit`.
**English:** Input `apple.com` on port `443`. Result: grade `A+`, protocols `TLS 1.2 · TLS 1.3`, certificate trusted, `70d` remaining, key `EC 256-bit`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** الدرجة تقريبية ومقصورة على ما يمكن لـ iOS ملاحظته أصلًا (لا فحص لمجموعات التشفير التفصيلية). فحص الإصدارات القديمة `TLS 1.0/1.1` يستخدم قيمًا خام لأن ثوابتها موقوفة. الاتصال مباشر من جهازك؛ لا يتطلب أذونات خاصة على iOS.
**English:** The grade is heuristic and scoped to what iOS can natively observe (no detailed cipher-suite inspection). Legacy `TLS 1.0/1.1` probing uses raw wire values since their constants are deprecated. The connection is direct from your device; no special iOS permissions are required.
