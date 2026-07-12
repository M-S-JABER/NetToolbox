# CIDR Aggregator · مُجمِّع كتل CIDR

> **Category / التصنيف:** Calculators / الحاسبات  
> **Tool ID:** `cidr-aggregate`

---

## نظرة عامة · Overview
**بالعربي:** أداة تدمج قائمة من عناوين وكتل IPv4 (CIDR) في أصغر مجموعة ممكنة من كتل CIDR تغطّي المجال نفسه تماماً — لا أكثر ولا أقل. مفيدة لتبسيط قوائم الوصول (ACL) وجداول التوجيه. تعمل محلياً بالكامل بدون إنترنت.  
**English:** Merges a list of IPv4 addresses/CIDR blocks into the minimal set of CIDR blocks that covers exactly the same address space — no more, no less. Useful for simplifying ACLs and routing tables. Runs 100% on-device with no network.

## كيف تعمل · How it works
**بالعربي:** يُقسَّم المدخل على الأسطر أو الفواصل أو المسافات أو علامات الجدولة. يُحلَّل كل سطر إلى مجال `[start, end]` بحساب حسابي بأعداد 64-بت (UInt64) لتفادي فيض الـ 32-بت عند الحدود: يُحسب القناع من طول البادئة، والشبكة = IP & mask، والنهاية = network + size − 1. البادئة المفقودة تعني `/32` (مضيف واحد)، أمّا بادئة غير رقمية (مثل `/xyz`) فتُرفَض كسطر معطوب. ثم تُرتَّب المجالات وتُدمَج المتلاصقة أو المتداخلة (شرط `range.start ≤ last.end + 1`). أخيراً يُحوَّل كل مجال مدموج إلى أقل عدد من كتل CIDR عبر خوارزمية تختار في كل خطوة أكبر كتلة محاذية لبداية المجال وتتّسع ضمن ما تبقّى (باستخدام `trailingZeroBitCount` للمحاذاة و`leadingZeroBitCount` للاتساع). المنطق محلي بالكامل ويعيد استخدام `SubnetEngine.parseIPv4`.  
**English:** Input is split on newlines, commas, spaces, or tabs. Each line is parsed into a `[start, end]` range using 64-bit (UInt64) arithmetic to avoid 32-bit overflow at the extremes: the mask is computed from the prefix length, network = IP & mask, end = network + size − 1. A missing prefix means `/32` (a single host); a non-numeric prefix (e.g. `/xyz`) is rejected as a malformed line. Ranges are then sorted and adjacent/overlapping ones merged (when `range.start ≤ last.end + 1`). Finally each merged range is converted to the fewest CIDR blocks by, at each step, choosing the largest block that is aligned to the range start and fits within what remains (using `trailingZeroBitCount` for alignment and `leadingZeroBitCount` for fit). All logic is local and reuses `SubnetEngine.parseIPv4`.

## المدخلات · Inputs
**بالعربي:**
- `List` — قائمة عناوين/كتل IPv4، كل عنصر على سطر أو مفصولاً بفاصلة/مسافة. يقبل صيغة CIDR (`10.0.0.0/24`) أو IP مجرداً (يُعامَل كـ `/32`). الأسطر المعطوبة تُتجاهَل.

**English:**
- `List` — a list of IPv4 addresses/blocks, one per line or comma/space separated. Accepts CIDR notation (`10.0.0.0/24`) or a bare IP (treated as `/32`). Malformed lines are skipped.

## المخرجات · Outputs
**بالعربي:** قائمة بكتل CIDR الناتجة (كل واحدة قابلة للنسخ) مع زر لنسخها جميعاً مفصولة بأسطر. القائمة هي أصغر تمثيل يغطّي نفس مجموعة العناوين المُدخَلة.  
**English:** A list of the resulting CIDR blocks (each copyable) plus a button to copy them all newline-separated. The list is the smallest representation covering exactly the same set of input addresses.

## مثال تشغيل · Worked example
**بالعربي:** إدخال `192.168.0.0/25` و`192.168.0.128/25` يُدمَج إلى `192.168.0.0/24`. وإدخال `10.0.0.0/24, 10.0.1.0/24` يُنتج `10.0.0.0/23`.  
**English:** Input `192.168.0.0/25` and `192.168.0.128/25` merges into `192.168.0.0/24`. Input `10.0.0.0/24, 10.0.1.0/24` yields `10.0.0.0/23`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** IPv4 فقط؛ لا يدعم IPv6. تُتجاهَل الأسطر التي لا تُحلَّل (IP غير صالح أو بادئة غير رقمية أو خارج المجال 0–32). لا اتصال بالشبكة إطلاقاً. النتيجة تغطّي المجال نفسه بالضبط دون توسيع إلى مضيفات إضافية.  
**English:** IPv4 only; IPv6 is not supported. Lines that fail to parse (invalid IP, non-numeric prefix, or prefix outside 0–32) are skipped. No network access at all. The result covers exactly the same range without widening to extra hosts.
