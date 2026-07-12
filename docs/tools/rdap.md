# RDAP · استعلام RDAP

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `rdap`

---

## نظرة عامة · Overview
**بالعربي:** أداة تجلب بيانات التسجيل المنظّمة لنطاق أو عنوان IP عبر بروتوكول RDAP، وهو الخلف الحديث لبروتوكول WHOIS ويعيد بيانات بصيغة JSON. تستخدم خدمة `rdap.org` كنقطة إقلاع (bootstrap) توجّه الاستعلام تلقائيًا إلى السجل المخوّل.

**English:** Fetches structured registration data for a domain or IP address via RDAP, the modern successor to WHOIS that returns JSON. It uses the `rdap.org` bootstrap service to automatically route the query to the authoritative registry.

## كيف تعمل · How it works
**بالعربي:** تُحدِّد الأداة نوع الاستعلام تلقائيًا: إذا احتوى النص على `:` أو كان مكوّنًا من أرقام ونقاط فقط يُعامَل كعنوان IP (`ip`)، وإلا كنطاق (`domain`). تُرسِل طلب `GET` إلى `https://rdap.org/<ip|domain>/<query>` (المنفذ `443`) مع الترويسة `Accept: application/rdap+json`، ومهلة `15` ثانية عبر `URLSession` بإعداد `ephemeral`. تُفكَّك استجابة JSON لاستخراج: الاسم (`ldhName`)، والمعرّف (`handle`)، والحالات (`status`)، والأحداث (`events` مع الإجراء والتاريخ)، وخوادم الأسماء (`nameservers`)، واسم المُسجِّل من مصفوفات vCard للكيانات ذات دور `registrar`/`registrant`.

**English:** The tool auto-detects the query kind: if the text contains `:` or consists only of digits and dots it is treated as an IP (`ip`), otherwise as a domain (`domain`). It sends a `GET` request to `https://rdap.org/<ip|domain>/<query>` (port `443`) with header `Accept: application/rdap+json`, a `15`-second timeout over an `ephemeral` `URLSession`. The JSON response is parsed to extract: name (`ldhName`), handle (`handle`), statuses (`status`), events (`events` with action and date), nameservers (`nameservers`), and the registrar name from the vCard arrays of entities with a `registrar`/`registrant` role.

## المدخلات · Inputs
- **Query / الاستعلام:** اسم نطاق (مثل `example.com`) أو عنوان IP (مثل `8.8.8.8` أو IPv6) · a domain name or an IP address.

## المخرجات · Outputs
**بالعربي:** بطاقة نتيجة تعرض الاسم والمُسجِّل والمعرّف، ثم قوائم (عند توفّرها) للأحداث (مثل `registration: 1995-08-14`)، والحالات (مثل `client transfer prohibited`)، وخوادم الأسماء. عند فشل الاستعلام أو استجابة `404` تظهر رسالة خطأ.

**English:** A result card showing the name, registrar, and handle, then lists (when available) of events (e.g. `registration: 1995-08-14`), statuses (e.g. `client transfer prohibited`), and nameservers. On failure or a `404` response, an error message is shown.

## مثال تشغيل · Worked example
**بالعربي:** الاستعلام `example.com`. الناتج النموذجي: الاسم `example.com`، المُسجِّل `Internet Assigned Numbers Authority`، أحداث تشمل `registration: 1995-08-14` و`expiration: 2025-08-13`، وحالات مثل `client delete prohibited`. أما الاستعلام `8.8.8.8` فيُعامَل كعنوان IP ويعيد بيانات كتلة Google.

**English:** Query `example.com`. Typical output: name `example.com`, registrar `Internet Assigned Numbers Authority`, events including `registration: 1995-08-14` and `expiration: 2025-08-13`, and statuses like `client delete prohibited`. The query `8.8.8.8` is treated as an IP and returns Google's block data.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** يتطلّب اتصالاً بالإنترنت. يعتمد على خدمة `rdap.org` للإقلاع؛ بعض الامتدادات القديمة قد لا تدعم RDAP وترجع `404`. مثل WHOIS، كثير من الحقول الشخصية مُخفاة لأسباب الخصوصية. عبر HTTPS على المنفذ `443` فهو أكثر قابلية للعمل عبر الشبكات المقيّدة من WHOIS على المنفذ `43`.

**English:** Requires an internet connection. It relies on the `rdap.org` bootstrap; some legacy TLDs may not support RDAP and return `404`. As with WHOIS, many personal fields are redacted for privacy. Being over HTTPS on port `443`, it works across restricted networks more reliably than WHOIS on port `43`.
