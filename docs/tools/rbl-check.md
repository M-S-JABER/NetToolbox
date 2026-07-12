# RBL / DNSBL Check · فحص القوائم السوداء

> **Category / التصنيف:** Security / الأمان  
> **Tool ID:** `rbl-check`

---

## نظرة عامة · Overview
**بالعربي:** أداة فحص RBL تتحقق مما إذا كان عنوان IPv4 مُدرجًا في قوائم حظر عامة قائمة على DNS (DNSBL/RBL) تُستخدم لمكافحة البريد المزعج. تستعلم عن عدة مناطق حظر معروفة وتبيّن أيها يُدرج العنوان. الاستعلام حقيقي عبر DNS.
**English:** The RBL Check tool tests whether an IPv4 address is listed on public DNS-based blocklists (DNSBL/RBL) used for anti-spam. It queries several well-known blocklist zones and shows which ones list the address. The lookup is a real DNS query.

## كيف تعمل · How it works
**بالعربي:** لكل منطقة حظر تبني الأداة اسم استعلام DNS-based blocklist بعكس ثمانيات عنوان IPv4 ثم إلحاق اسم المنطقة (مثل `4.3.2.1.zen.spamhaus.org` للعنوان `1.2.3.4`). يُرسَل استعلام من نوع `A` عبر `UDPDNSResolver` إلى الخادم `1.1.1.1` على المنفذ `53` (UDP). إن عاد أي سجل `A` فالعنوان **مُدرج** في تلك المنطقة؛ وإلا فهو **نظيف**. المناطق المفحوصة: `zen.spamhaus.org`، `bl.spamcop.net`، `b.barracudacentral.org`، `dnsbl.sorbs.net`، `cbl.abuseat.org`، `dnsbl-1.uceprotect.net`. تُفحص المناطق تتابعيًا.
**English:** For each blocklist zone the tool builds a DNSBL query name by reversing the octets of the IPv4 address and appending the zone (e.g. `4.3.2.1.zen.spamhaus.org` for `1.2.3.4`). An `A`-type query is sent via `UDPDNSResolver` to server `1.1.1.1` on port `53` (UDP). If any `A` record is returned, the address is **listed** on that zone; otherwise it is **clean**. The zones checked are: `zen.spamhaus.org`, `bl.spamcop.net`, `b.barracudacentral.org`, `dnsbl.sorbs.net`, `cbl.abuseat.org`, `dnsbl-1.uceprotect.net`. Zones are checked sequentially.

## المدخلات · Inputs
- **IP address / عنوان IP:** عنوان IPv4 (مثل `8.8.8.8`). المدخل غير الصالح كعنوان IPv4 يُرفض. / An IPv4 address; input that is not a valid IPv4 address is rejected.

## المخرجات · Outputs
**بالعربي:** بشارة إجمالية: `clean` (خضراء) إذا لم يُدرج في أي منطقة، أو `listed` (حمراء) إذا أُدرج في واحدة أو أكثر. ثم قائمة بكل منطقة ورمز حالتها: علامة صح خضراء (نظيف) أو ثماني أحمر (مُدرج).
**English:** An overall badge: `clean` (green) if not listed anywhere, or `listed` (red) if on one or more zones. Then a list of each zone with its status icon: a green check (clean) or a red octagon (listed).

## مثال تشغيل · Worked example
**بالعربي:** المدخل `8.8.8.8`. تبني الأداة استعلامات مثل `8.8.8.8.zen.spamhaus.org`، ولا يعود أي سجل `A`، فتظهر البشارة `clean` وكل المناطق نظيفة.
**English:** Input `8.8.8.8`. The tool builds queries such as `8.8.8.8.zen.spamhaus.org`; no `A` record returns, so the badge shows `clean` and all zones are clean.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** تدعم IPv4 فقط. بعض مناطق الحظر العامة تفرض حدودًا على الاستعلامات من مُحلِّلات مشتركة كـ `1.1.1.1` وقد تعيد نتائج غير حاسمة. الإدراج/الرفع يتغيّران بمرور الوقت. لا يتطلب أذونات خاصة على iOS.
**English:** IPv4 only. Some public blocklist zones rate-limit queries from shared resolvers like `1.1.1.1` and may return inconclusive results. Listing/delisting changes over time. No special iOS permissions are required.
