# Subnet Membership · انتماء عنوان لشبكة فرعية

> **Category / التصنيف:** Calculators / الحاسبات  
> **Tool ID:** `subnet-membership`

---

## نظرة عامة · Overview
**بالعربي:** أداة تُجيب على سؤال بسيط ومهم: هل عنوان `IP` معيّن يقع داخل شبكة فرعية `CIDR` محددة أم خارجها؟ إضافة إلى الحكم بالانتماء، تعرض تفاصيل الشبكة الفرعية (عنوان الشبكة، أول وآخر مضيف، البث) لتأكيد النطاق بصرياً. مفيدة للتحقق من قواعد ACL والتوجيه وتصميم العناوين.
**English:** A tool that answers one simple, important question: does a given `IP` fall inside a specific `CIDR` subnet or outside it? Besides the in/out verdict, it shows the subnet details (network address, first/last host, broadcast) so you can confirm the range visually. Useful for validating ACLs, routing, and address planning.

## كيف تعمل · How it works
**بالعربي:** المنطق في `IPTools.contains` فوق `SubnetEngine`، وهو حساب رياضي صرف — **يعمل محلياً بالكامل بدون اتصال بالإنترنت**. يُحسب قناع الشبكة من طول البادئة، ثم يقارن العنوان المُدخل مع عنوان الشبكة بعد تطبيق القناع على كليهما: إذا كان `(ip & mask) == (network & mask)` فالعنوان داخل الشبكة. إن لم تحتوِ سلسلة `CIDR` على `/` يُفترض `/24`. يعتمد فقط على `Foundation`.
**English:** The logic lives in `IPTools.contains` on top of `SubnetEngine`, pure math — **runs 100% on-device, no network**. It derives the network mask from the prefix length, then compares the input address against the network address after masking both: if `(ip & mask) == (network & mask)` the address is inside the subnet. If the `CIDR` string has no `/`, `/24` is assumed. Depends only on `Foundation`.

## المدخلات · Inputs
| Field · الحقل | الوصف · Description |
|---|---|
| `ip` | عنوان `IPv4` المراد فحصه، مثل `192.168.1.50`. The IPv4 address to test. |
| `cidr` | الشبكة الفرعية بصيغة `CIDR` مثل `192.168.1.0/24` (أو بدون `/` فيُفترض `/24`). The subnet in CIDR form. |

## المخرجات · Outputs
**بالعربي:** شارة حالة (داخل / خارج)، ثم عنوان الشبكة بصيغة `CIDR`، وأول مضيف صالح، وآخر مضيف صالح، وعنوان البث. عند إدخال غير صالح تظهر رسالة خطأ.
**English:** A status badge (inside / outside), then the network address in `CIDR`, first usable host, last usable host, and broadcast address. Invalid input shows an error message.

## مثال تشغيل · Worked example
**بالعربي:** IP = `192.168.1.50`، CIDR = `192.168.1.0/24` →
- النتيجة: **داخل الشبكة** ✔
- الشبكة: `192.168.1.0/24` · أول مضيف: `192.168.1.1` · آخر مضيف: `192.168.1.254` · البث: `192.168.1.255`

مثال خارج النطاق: IP = `10.0.0.5` مع نفس `CIDR` → **خارج الشبكة**.

**English:** IP = `192.168.1.50`, CIDR = `192.168.1.0/24` →
- Result: **inside** ✔
- Network: `192.168.1.0/24` · First: `192.168.1.1` · Last: `192.168.1.254` · Broadcast: `192.168.1.255`

Out-of-range example: IP = `10.0.0.5` with the same `CIDR` → **outside**.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** خاص بـ IPv4 فقط. لا اتصال بالشبكة إطلاقاً — الحساب على الجهاز. العنوان أو الـ CIDR غير الصالح يُنتج رسالة خطأ بدل نتيجة.
**English:** IPv4 only. No network access whatsoever — all on-device. An invalid address or CIDR produces an error instead of a result.
