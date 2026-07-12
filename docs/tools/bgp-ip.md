# IP → BGP Origin · تحويل IP إلى نظام المصدر (BGP)

> **Category / التصنيف:** BGP / التوجيه العالمي (BGP)  
> **Tool ID:** `bgp-ip`

---

## نظرة عامة · Overview
**بالعربي:** أداة تُحوِّل عنوان IP (أو بادئة) إلى البادئة (prefix) التي تغطّيه في التوجيه العالمي، وإلى نظام/أنظمة المصدر (Origin AS) التي تُعلن عنه. تعتمد على واجهة بيانات **RIPEstat** العامة على `stat.ripe.net` بلا مفتاح.
**English:** Resolves an IP address (or prefix) to the covering prefix in the global routing table and to the origin AS(es) announcing it. It uses the public **RIPEstat** data API at `stat.ripe.net`, no key required.

## كيف تعمل · How it works
**بالعربي:** تستدعي الأداة نقطة `network-info` من RIPEstat بصيغة `https://stat.ripe.net/data/network-info/data.json?resource=<ip>&sourceapp=nettoolbox` للحصول على البادئة المغطّية وقائمة أرقام الأنظمة. ثم إن توفّرت بادئة تستدعي `prefix-overview` لجلب أرقام الأنظمة مع أسماء مالكيها. إذا لم تُرجِع `prefix-overview` نتائج، تُستخدم الأنظمة من `network-info` كبديل (بلا اسم مالك).
**English:** The tool calls RIPEstat's `network-info` endpoint as `https://stat.ripe.net/data/network-info/data.json?resource=<ip>&sourceapp=nettoolbox` to get the covering prefix and AS numbers. If a prefix is found it then calls `prefix-overview` to fetch AS numbers with their holder names. If `prefix-overview` returns nothing, the AS numbers from `network-info` are used as a fallback (without holder names).

## المدخلات · Inputs
- **الاستعلام / Query:** عنوان IP أو بادئة، الافتراضي `8.8.8.8` · An IP address or prefix, default `8.8.8.8`.

## المخرجات · Outputs
**بالعربي:** بطاقة تعرض: الاستعلام الأصلي، البادئة المغطّية، ثم قائمة أنظمة المصدر كل منها بصيغة `AS<رقم>` مع اسم المالك. إن لم تُوجد أنظمة مصدر تظهر رسالة "فارغ".
**English:** A card showing: the original query, the covering prefix, then the list of origin ASes each as `AS<number>` with holder name. If no origins are found an "empty" message is shown.

## مثال تشغيل · Worked example
**بالعربي:** الإدخال: `8.8.8.8`. النتيجة:
`Query: 8.8.8.8`، `Prefix: 8.8.8.0/24`، والمصدر: `AS15169 — GOOGLE`.
**English:** Input: `8.8.8.8`. Result:
`Query: 8.8.8.8`, `Prefix: 8.8.8.0/24`, and origin: `AS15169 — GOOGLE`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** تتطلب اتصال إنترنت للوصول إلى `stat.ripe.net`. البيانات من RIPEstat وتعكس رصد مجمّعات RIPE للتوجيه العالمي. قد يُعلن عن البادئة أكثر من نظام مصدر واحد (multi-origin). تُرسَل الاستعلامات مع الوسم `sourceapp=nettoolbox`. تعمل مع IPv4 وIPv6 والبادئات.
**English:** Requires internet access to reach `stat.ripe.net`. Data comes from RIPEstat and reflects RIPE's collector view of global routing. A prefix may be announced by more than one origin AS (multi-origin). Queries carry the `sourceapp=nettoolbox` tag. Works with IPv4, IPv6, and prefixes.
