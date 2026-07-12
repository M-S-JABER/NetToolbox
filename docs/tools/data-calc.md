# Data & Transfer Calculator · حاسبة البيانات وزمن النقل

> **Category / التصنيف:** Calculators / الحاسبات  
> **Tool ID:** `data-calc`

---

## نظرة عامة · Overview
**بالعربي:** أداة تحوّل حجم بيانات بين الوحدات (بالنظام العشري والثنائي) وتُقدّر الزمن اللازم لنقله عند سرعة معيّنة. تُظهر أيضاً الحجم بالبايت وبالميغابِت. تعمل محلياً بالكامل بدون إنترنت.  
**English:** Converts a data size between units (decimal and binary) and estimates the time to transfer it at a given speed. Also shows the size in bytes and in megabits. Runs 100% on-device with no network.

## كيف تعمل · How it works
**بالعربي:** يُحوَّل الحجم إلى بايتات حسب الوحدة: العشرية بأساس 1000 (`KB`=1,000، `MB`=1,000,000، `GB`=1e9، `TB`=1e12) والثنائية بأساس 1024 (`KiB`=1024، `MiB`=1024²، `GiB`=1024³). وتُحوَّل السرعة إلى بِت/ثانية (`Kbps`=1e3، `Mbps`=1e6، `Gbps`=1e9). زمن النقل = (الحجم بالبايت × 8) ÷ (بِت/ثانية). يُنسَّق الزمن للقراءة: أقل من ثانية بالميلي ثانية، وإلا بصيغة `Xh Ym Zs`. هناك حماية من الفيض: إذا كانت السرعة صفراً يكون الزمن صفراً، وإذا تجاوز الزمن حدّ `Int.max` يُعرَض `∞`. كل الحساب محلي عبر أرقام عشرية (Double).  
**English:** The size is converted to bytes by unit: decimal base 1000 (`KB`=1,000, `MB`=1,000,000, `GB`=1e9, `TB`=1e12) and binary base 1024 (`KiB`=1024, `MiB`=1024², `GiB`=1024³). Speed is converted to bits/second (`Kbps`=1e3, `Mbps`=1e6, `Gbps`=1e9). Transfer time = (size in bytes × 8) ÷ (bits/second). The time is humanized: under a second in milliseconds, otherwise as `Xh Ym Zs`. Overflow is guarded: a zero speed gives zero time, and if the time exceeds `Int.max` it displays `∞`. All computation is local using Double arithmetic.

## المدخلات · Inputs
**بالعربي:**
- `Size` — قيمة الحجم (عدد عشري) + منتقي الوحدة من `KB, MB, GB, TB, KiB, MiB, GiB` (الافتراضي `GB`).
- `Speed` — قيمة السرعة (عدد عشري) + منتقي الوحدة من `Kbps, Mbps, Gbps` (الافتراضي `Mbps`).

**English:**
- `Size` — the size value (decimal number) + a unit picker from `KB, MB, GB, TB, KiB, MiB, GiB` (default `GB`).
- `Speed` — the speed value (decimal number) + a unit picker from `Kbps, Mbps, Gbps` (default `Mbps`).

## المخرجات · Outputs
**بالعربي:**
- زمن النقل المُقدَّر بصيغة مقروءة كبيرة الخط (`Xh Ym Zs` أو ميلي ثانية).
- `Bytes` — الحجم بالبايت.
- `Megabits` — الحجم بالميغابِت (بايت × 8 ÷ 1,000,000).

**English:**
- The estimated transfer time in a large humanized form (`Xh Ym Zs` or milliseconds).
- `Bytes` — the size in bytes.
- `Megabits` — the size in megabits (bytes × 8 ÷ 1,000,000).

## مثال تشغيل · Worked example
**بالعربي:** حجم `1 GB` بسرعة `100 Mbps`: البايتات = 1,000,000,000، الميغابِت = 8000.00، وزمن النقل = 8,000,000,000 بِت ÷ 100,000,000 = 80 ثانية، فيُعرَض `1m 20s`.  
**English:** Size `1 GB` at `100 Mbps`: bytes = 1,000,000,000, megabits = 8000.00, and transfer time = 8,000,000,000 bits ÷ 100,000,000 = 80 seconds, shown as `1m 20s`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** الوحدات العشرية (KB/MB/GB/TB) بأساس 1000، والثنائية (KiB/MiB/GiB) بأساس 1024 — انتبه للفرق. الزمن تقدير مثالي يفترض استغلال السرعة كاملة دون overhead أو تأخير أو فقد. سرعة صفر تعطي `—`. القيم الضخمة جداً قد تُعرَض `∞`. لا اتصال بالشبكة إطلاقاً.  
**English:** Decimal units (KB/MB/GB/TB) use base 1000 and binary units (KiB/MiB/GiB) use base 1024 — mind the difference. The time is an ideal estimate assuming full speed utilization with no overhead, latency, or loss. A zero speed shows `—`. Extremely large values may display `∞`. No network access at all.
