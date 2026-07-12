# BGP ASN Lookup · بحث عن رقم النظام الذاتي (ASN)

> **Category / التصنيف:** BGP / التوجيه العالمي (BGP)  
> **Tool ID:** `bgp-asn`

---

## نظرة عامة · Overview
**بالعربي:** أداة تستعلم عن رقم نظام ذاتي (Autonomous System Number) في التوجيه العالمي BGP، فتُظهر اسم المالك ونوعه وعدد الجيران وقائمة البادئات (prefixes) المُعلَن عنها. تعتمد على واجهة بيانات **RIPEstat** العامة على `stat.ripe.net` بلا مفتاح.
**English:** Looks up an Autonomous System Number in the global BGP routing table, showing the holder name, type, neighbour count, and the list of announced prefixes. It uses the public **RIPEstat** data API at `stat.ripe.net`, no key required.

## كيف تعمل · How it works
**بالعربي:** تُطبّع الأداة المُدخَل إلى صيغة رقمية (تقبل `AS15169` أو `as15169` أو `15169`)، ثم تستدعي ثلاث نقاط من واجهة RIPEstat عبر HTTPS بصيغة `https://stat.ripe.net/data/<call>/data.json?resource=<asn>&sourceapp=nettoolbox`:
- `as-overview` → اسم المالك ونوع النظام.
- `announced-prefixes` → قائمة البادئات المُعلَنة.
- `asn-neighbours` → قائمة الجيران (يُحسب عددهم).
تُفكّ ردود JSON وتُجمَّع في نتيجة واحدة.
**English:** The tool normalizes the input to a numeric form (accepts `AS15169`, `as15169`, or `15169`), then calls three RIPEstat endpoints over HTTPS in the form `https://stat.ripe.net/data/<call>/data.json?resource=<asn>&sourceapp=nettoolbox`:
- `as-overview` → holder name and AS type.
- `announced-prefixes` → the list of announced prefixes.
- `asn-neighbours` → the neighbour list (counted).
The JSON responses are decoded and merged into a single result.

## المدخلات · Inputs
- **الاستعلام / Query:** رقم النظام الذاتي بأي صيغة، الافتراضي `AS15169` · The AS number in any form, default `AS15169`.

## المخرجات · Outputs
**بالعربي:** بطاقة نظرة عامة تعرض: رقم ASN، المالك (Holder)، النوع، عدد الجيران، وعدد البادئات. ثم قائمة بالبادئات المُعلَنة (حتى 200 بادئة تُعرض) القابلة للتحديد.
**English:** An overview card showing: the ASN, the holder, the type, the neighbour count, and the prefix count. Then a list of announced prefixes (up to 200 shown), selectable.

## مثال تشغيل · Worked example
**بالعربي:** الإدخال: `AS15169` (Google). النتيجة:
`ASN: 15169`، `Holder: GOOGLE`، `Type: content`، `Neighbours: 200+`، وقائمة بادئات تتضمن `8.8.8.0/24`، `8.8.4.0/24`، `142.250.0.0/15` …
**English:** Input: `AS15169` (Google). Result:
`ASN: 15169`, `Holder: GOOGLE`, `Type: content`, `Neighbours: 200+`, and a prefix list including `8.8.8.0/24`, `8.8.4.0/24`, `142.250.0.0/15` …

## ملاحظات وقيود · Notes & limitations
**بالعربي:** تتطلب اتصال إنترنت للوصول إلى `stat.ripe.net`. البيانات مصدرها RIPEstat وتعكس ما ترصده مجمّعات RIPE من التوجيه العالمي (قد يوجد تأخّر أو تفاوت طفيف عن الواقع اللحظي). تُرسَل الاستعلامات مع الوسم `sourceapp=nettoolbox`. تُعرض أول 200 بادئة فقط في الواجهة. استعلام ASN يتطلب أكثر من رقمين صالحين.
**English:** Requires internet access to reach `stat.ripe.net`. Data comes from RIPEstat and reflects what RIPE's collectors observe of global routing (there may be slight delay or divergence from the live state). Queries carry the `sourceapp=nettoolbox` tag. Only the first 200 prefixes are shown in the UI. The ASN query requires more than two valid digits.
