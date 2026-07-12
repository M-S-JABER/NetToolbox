# VLSM Calculator · حاسبة VLSM (أقنعة الطول المتغير)

> **Category / التصنيف:** Calculators / الحاسبات  
> **Tool ID:** `vlsm`

---

## نظرة عامة · Overview
**بالعربي:** أداة تقسيم شبكة أساسية إلى عدة شبكات فرعية بأحجام مختلفة (Variable-Length Subnet Masking). تُدخل شبكة أساسية بصيغة `CIDR` وقائمة من الطلبات، كل طلب باسم وعدد المضيفين المطلوب، فتُوزّع الأداة الشبكات الفرعية بإحكام (الأكبر أولاً) وتُعطي لكل طلب نطاقه الكامل. مثالية لتصميم عنونة فعّالة بلا هدر.
**English:** A tool for splitting one base network into several differently-sized subnets (Variable-Length Subnet Masking). You enter a base `CIDR` and a list of requests — each with a name and a required host count — and the tool packs the subnets tightly (largest first), giving each request its full range. Ideal for efficient address planning with minimal waste.

## كيف تعمل · How it works
**بالعربي:** المنطق في `VLSMEngine.allocate` فوق `SubnetEngine`، حساب رياضي صرف — **يعمل محلياً بالكامل بدون اتصال بالإنترنت**. الخطوات: (1) تجاهل الطلبات ذات المضيفين ≤ 0، (2) لكل طلب حساب أصغر بادئة تكفي عدد المضيفين المطلوب (مع مراعاة عنوان الشبكة والبث للبادئات ≤ /30)، (3) ترتيب الطلبات تنازلياً حسب الحجم للتعبئة المحكمة، (4) محاذاة المؤشر لبداية كل بلوك على حدوده الصحيحة ثم تخصيص المدى. تُجرى كل عمليات العناوين بـ `UInt64` لتفادي أي تجاوز. إن لم تتّسع الشبكة الأساسية للطلبات يظهر خطأ "لا يتّسع".
**English:** Logic lives in `VLSMEngine.allocate` on top of `SubnetEngine`, pure math — **runs 100% on-device, no network**. Steps: (1) drop requests with ≤ 0 hosts, (2) for each request compute the smallest prefix that fits the required hosts (accounting for network + broadcast at prefixes ≤ /30), (3) sort requests largest-first for tight packing, (4) align the cursor to each block's boundary then allocate the range. All address math is done in `UInt64` to avoid overflow. If the base network can't fit the requests, a "does not fit" error is shown.

## المدخلات · Inputs
| Field · الحقل | الوصف · Description |
|---|---|
| `baseCIDR` | الشبكة الأساسية، مثل `192.168.1.0/24`. The base network to carve up. |
| `requests[]` | قائمة طلبات، كل عنصر: `name` (اسم القسم) و`hosts` (عدد المضيفين المطلوب). List of requests, each with a name and required host count. |

## المخرجات · Outputs
**بالعربي:** لكل طلب صف يعرض: الاسم، الشبكة بصيغة `CIDR`، قناع الشبكة، مدى المضيفين (أول – آخر)، وشارة تُظهر `المطلوب/المتاح`. عند الخطأ تظهر رسالة (لا توجد طلبات، أو لا يتّسع).
**English:** Each request produces a row showing: name, network in `CIDR`, subnet mask, host range (first – last), and a badge showing `requested/available`. On error a message appears (no requests, or does not fit).

## مثال تشغيل · Worked example
**بالعربي:** الأساس `192.168.1.0/24`، طلبان: `Sales` = 50 مضيف، `IT` = 20 مضيف →
- `Sales`: `192.168.1.0/26` — القناع `255.255.255.192` — المضيفون `192.168.1.1 – 192.168.1.62` (62 متاح لطلب 50)
- `IT`: `192.168.1.64/27` — القناع `255.255.255.224` — المضيفون `192.168.1.65 – 192.168.1.94` (30 متاح لطلب 20)

**English:** Base `192.168.1.0/24`, two requests: `Sales` = 50 hosts, `IT` = 20 hosts →
- `Sales`: `192.168.1.0/26` — mask `255.255.255.192` — hosts `192.168.1.1 – 192.168.1.62` (62 available for 50 requested)
- `IT`: `192.168.1.64/27` — mask `255.255.255.224` — hosts `192.168.1.65 – 192.168.1.94` (30 available for 20 requested)

## ملاحظات وقيود · Notes & limitations
**بالعربي:** IPv4 فقط. الطلبات ذات المضيفين صفر أو سالب تُتجاهل. الطلب الفارغ الاسم يُسمّى تلقائياً "Subnet". لا اتصال بالإنترنت. إن تجاوز مجموع الأحجام سعة الشبكة الأساسية يفشل التخصيص برسالة خطأ.
**English:** IPv4 only. Requests with zero or negative hosts are ignored. An unnamed request is auto-labeled "Subnet". No internet access. If the combined sizes exceed the base capacity, allocation fails with an error.
