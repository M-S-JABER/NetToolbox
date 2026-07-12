# Number Base Converter · محوّل الأنظمة العددية

> **Category / التصنيف:** Calculators / الحاسبات  
> **Tool ID:** `number-converter`

---

## نظرة عامة · Overview
**بالعربي:** أداة تحويل رقم واحد بين أربعة أنظمة عددية: الثنائي (BIN)، الثماني (OCT)، العشري (DEC)، والست عشري (HEX). تكتشف نظام الإدخال تلقائياً من البادئة وتعرض القيمة نفسها في الأنظمة الأربعة فوراً أثناء الكتابة. مفيدة للمبرمجين ومهندسي الشبكات عند العمل مع الأقنعة والرايات (flags) والقيم الست عشرية.
**English:** A tool that converts a single number between four bases: binary (BIN), octal (OCT), decimal (DEC), and hexadecimal (HEX). It auto-detects the input base from a prefix and instantly shows the same value in all four bases as you type. Handy for developers and network engineers working with masks, flags, and hex values.

## كيف تعمل · How it works
**بالعربي:** المنطق في `NumberConverter` وهو تحويل صرف حتى 64 بت — **يعمل محلياً بالكامل بدون اتصال بالإنترنت**. الدالة `parse` تكتشف النظام من البادئة: `0x` ست عشري، `0b` ثنائي، `0o` ثماني، وبلا بادئة يُفترض عشري. تتجاهل الشرطة السفلية `_` كفاصل قراءة. عند فشل التحويل تُميّز بين "تجاوز الحد" (أحرف صحيحة لكن القيمة أكبر من 64 بت) و"إدخال غير صالح" (أحرف غير مسموحة). الإخراج يُنسّق الثنائي في مجموعات من 4 خانات لسهولة القراءة. يعتمد على `Foundation` فقط.
**English:** Logic lives in `NumberConverter`, a pure conversion up to 64 bits — **runs 100% on-device, no network**. The `parse` function detects the base from a prefix: `0x` hex, `0b` binary, `0o` octal, and no prefix means decimal. Underscores `_` are ignored as readability separators. On failure it distinguishes "overflow" (valid characters but the value exceeds 64 bits) from "invalid input" (disallowed characters). The output groups binary into nibbles of 4 for readability. Depends on `Foundation` only.

## المدخلات · Inputs
| Field · الحقل | الوصف · Description |
|---|---|
| `input` | رقم واحد؛ نظامه يُحدَّد بالبادئة `0x` / `0b` / `0o` أو يُفترض عشرياً بلا بادئة. المدى حتى 64 بت. A single number; base set by prefix or assumed decimal. Range up to 64 bits. |

## المخرجات · Outputs
**بالعربي:** أربعة صفوف تُحدَّث لحظياً: `HEX` (أحرف كبيرة)، `DEC`، `OCT`، و`BIN` (مجمّع في نيبلات). كل القيم قابلة للتحديد والنسخ. الإدخال الخاطئ يظهر كرسالة خطأ.
**English:** Four live-updating rows: `HEX` (uppercase), `DEC`, `OCT`, and `BIN` (grouped in nibbles). All values are selectable and copyable. Bad input shows an error message.

## مثال تشغيل · Worked example
**بالعربي:** إدخال `0xFF` →
- HEX: `FF` · DEC: `255` · OCT: `377` · BIN: `1111 1111`

إدخال `255` (عشري) يعطي نفس النتيجة. إدخال `0b1010` → HEX `A`, DEC `10`, OCT `12`, BIN `1010`.

**English:** Input `0xFF` →
- HEX: `FF` · DEC: `255` · OCT: `377` · BIN: `1111 1111`

Input `255` (decimal) gives the same result. Input `0b1010` → HEX `A`, DEC `10`, OCT `12`, BIN `1010`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** القيمة القصوى 64 بت (`0xFFFFFFFFFFFFFFFF`)؛ ما يتجاوزها يُظهر خطأ "تجاوز". أرقام صحيحة موجبة فقط (بلا كسور أو إشارة سالبة). لا اتصال بالإنترنت — الحساب على الجهاز.
**English:** Maximum value is 64-bit (`0xFFFFFFFFFFFFFFFF`); anything larger shows an "overflow" error. Positive integers only (no fractions or negative sign). No internet access — computed on-device.
