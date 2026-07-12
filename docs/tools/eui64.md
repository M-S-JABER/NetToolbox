# EUI-64 / SLAAC Builder · مُولِّد EUI-64 و SLAAC

> **Category / التصنيف:** Calculators / الحاسبات  
> **Tool ID:** `eui64`

---

## نظرة عامة · Overview
**بالعربي:** أداة تبني مُعرِّف الواجهة (interface identifier) بصيغة modified EUI-64 انطلاقاً من عنوان MAC، ثم تُركّب عنوان IPv6 الناتج عبر آلية SLAAC تحت بادئة (prefix) تحدّدها أنت. تعمل محلياً بالكامل بدون إنترنت.  
**English:** Builds a modified EUI-64 interface identifier from a MAC address, then composes the resulting SLAAC IPv6 address under a prefix you supply. Runs 100% on-device with no network.

## كيف تعمل · How it works
**بالعربي:** يُستخرج من عنوان MAC ما هو ست عشري فقط ويجب أن يكون 12 خانة (6 بايتات). ثم: (1) يُقلَب بِت universal/local في أعلى بايت (XOR مع `0x02`). (2) يُدرَج `FF:FE` في منتصف البايتات الستة لتصبح ثمانية: `[b0, b1, b2, FF, FE, b3, b4, b5]`. (3) تُجمَّع الثمانية في أربع مجموعات 16-بت. لبناء عنوان SLAAC تُؤخذ أول 4 مجموعات من البادئة (تُحلَّل عبر `SubnetEngine.parseIPv6`، والافتراضي `::` إن كانت فارغة) وتُدمَج مع مُعرِّف الواجهة، ثم يُضغَط العنوان بصيغة IPv6 المختصرة عبر `SubnetEngine.compressed`. كل المنطق محلي ويعيد استخدام مُحرّك الشبكات المُختبَر داخل التطبيق.  
**English:** Only hex digits are kept from the MAC and must total 12 (6 bytes). Then: (1) the universal/local bit of the top byte is flipped (XOR with `0x02`). (2) `FF:FE` is inserted into the middle to expand six bytes to eight: `[b0, b1, b2, FF, FE, b3, b4, b5]`. (3) The eight bytes are grouped into four 16-bit groups. For the SLAAC address, the first 4 groups of the prefix are parsed (via `SubnetEngine.parseIPv6`, defaulting to `::` when empty) and combined with the interface identifier, then the address is compressed to canonical IPv6 form via `SubnetEngine.compressed`. All logic is local and reuses the app's tested subnet engine.

## المدخلات · Inputs
**بالعربي:**
- `MAC` — عنوان MAC بأي فاصل (`:` أو `-` أو بدون فاصل)؛ تُقرأ الخانات الست عشرية فقط ويجب أن تكون 12.
- `Prefix` — بادئة IPv6 مع الطول، الافتراضي `fe80::/64`. يُتجاهَل جزء `/64` عند الحساب وتُستخدم أول 4 مجموعات فقط.

**English:**
- `MAC` — a MAC address with any separator (`:`, `-`, or none); only hex digits are read and must total 12.
- `Prefix` — an IPv6 prefix with length, default `fe80::/64`. The `/64` part is ignored for computation and only the first 4 groups are used.

## المخرجات · Outputs
**بالعربي:**
- `Interface ID` — مُعرِّف الواجهة بصيغة EUI-64 المعدّلة، أربع مجموعات مفصولة بـ `:`.
- `Address` — عنوان IPv6 الكامل الناتج بصيغة مختصرة. كلاهما قابل للنسخ. إذا كان MAC غير صالح تظهر رسالة خطأ.

**English:**
- `Interface ID` — the modified EUI-64 interface identifier, four groups separated by `:`.
- `Address` — the full resulting IPv6 address in compressed form. Both are copyable. If the MAC is invalid, an error message is shown.

## مثال تشغيل · Worked example
**بالعربي:** لعنوان `00:1A:2B:3C:4D:5E` وبادئة `fe80::/64`: يُقلَب البايت الأول `00` → `02`، ويُدرَج `FF:FE`، فيصبح مُعرِّف الواجهة `021a:2bff:fe3c:4d5e`، والعنوان الناتج `fe80::21a:2bff:fe3c:4d5e`.  
**English:** For `00:1A:2B:3C:4D:5E` with prefix `fe80::/64`: the first byte `00` flips to `02`, `FF:FE` is inserted, giving interface ID `021a:2bff:fe3c:4d5e` and address `fe80::21a:2bff:fe3c:4d5e`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** لا يقبل إلا 12 خانة ست عشرية بالضبط في MAC؛ أي طول آخر يُعتبر غير صالح. لا تُرسَل أي بيانات لأي خادم. تُستخدم أول 4 مجموعات من البادئة فقط (شبكة /64)؛ ما بعدها في البادئة يُتجاهَل. قلب بِت U/L قد لا يُطابق سلوك كل الأنظمة عملياً لكنه المعيار في modified EUI-64.  
**English:** The MAC must be exactly 12 hex digits; any other length is invalid. No data is sent to any server. Only the first 4 groups of the prefix are used (a /64 network); anything beyond that in the prefix is ignored. Flipping the U/L bit follows the modified EUI-64 standard even though some systems behave differently in practice.
