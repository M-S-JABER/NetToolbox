# Password Generator · مولّد كلمات المرور

> **Category / التصنيف:** Calculators / الحاسبات  
> **Tool ID:** `password-generator`

---

## نظرة عامة · Overview
**بالعربي:** أداة توليد كلمات مرور قوية وعشوائية بمعايير قابلة للتخصيص: الطول ومجموعات الأحرف (صغيرة، كبيرة، أرقام، رموز). تعرض تقديراً لقوة كلمة المرور بالبتات (entropy) مع تصنيف مرئي (ضعيفة/مقبولة/قوية/ممتازة) وزر نسخ. مناسبة لإنشاء بيانات اعتماد آمنة بسرعة.
**English:** A tool that generates strong, random passwords with customizable criteria: length and character sets (lowercase, uppercase, digits, symbols). It shows an entropy estimate in bits with a visual rating (weak/fair/strong/excellent) and a copy button. Great for quickly creating secure credentials.

## كيف تعمل · How it works
**بالعربي:** المنطق في `PasswordGenerator` — **يعمل محلياً بالكامل بدون اتصال بالإنترنت**. تُبنى مجموعة الأحرف (pool) من الخيارات المفعّلة، ثم تُسحب كل خانة من كلمة المرور عشوائياً باستخدام مولّد الأرقام العشوائي الآمن للنظام (`SystemRandomNumberGenerator` — وهو CSPRNG). تُقدَّر الإنتروبيا بالصيغة: `الطول × log2(حجم المجموعة)` بتاً، ويُصنَّف الناتج: أقل من 40 بت ضعيف، 40–70 مقبول، 70–100 قوي، وأكثر ممتاز. مجموعات الأحرف: صغيرة `a–z`، كبيرة `A–Z`، أرقام `0–9`، رموز `!@#$%^&*()-_=+[]{};:,.?/`.
**English:** Logic lives in `PasswordGenerator` — **runs 100% on-device, no network**. A character pool is built from the enabled options, then each character of the password is drawn using the system's secure random generator (`SystemRandomNumberGenerator`, a CSPRNG). Entropy is estimated as `length × log2(poolSize)` bits, and rated: under 40 bits weak, 40–70 fair, 70–100 strong, above excellent. Character sets: lowercase `a–z`, uppercase `A–Z`, digits `0–9`, symbols `!@#$%^&*()-_=+[]{};:,.?/`.

## المدخلات · Inputs
| Field · الحقل | الوصف · Description |
|---|---|
| `length` | طول كلمة المرور، منزلق من `6` إلى `64` (الافتراضي `16`). Password length slider, 6–64 (default 16). |
| `lowercase` | تضمين الأحرف الصغيرة. Include lowercase letters. |
| `uppercase` | تضمين الأحرف الكبيرة. Include uppercase letters. |
| `digits` | تضمين الأرقام. Include digits. |
| `symbols` | تضمين الرموز. Include symbols. |

## المخرجات · Outputs
**بالعربي:** كلمة المرور المولَّدة (قابلة للتحديد والنسخ)، شارة قوة ملوّنة (ضعيفة/مقبولة/قوية/ممتازة)، وقيمة الإنتروبيا بالبتات. زر إعادة التوليد يُنتج كلمة جديدة، وأي تغيير في الخيارات يعيد التوليد تلقائياً.
**English:** The generated password (selectable and copyable), a colored strength badge (weak/fair/strong/excellent), and the entropy in bits. A regenerate button produces a new one, and any option change auto-regenerates.

## مثال تشغيل · Worked example
**بالعربي:** الطول `16` مع تفعيل الأربع مجموعات (حجم المجموعة ≈ 85 حرفاً) →
- الإنتروبيا ≈ `16 × log2(85)` ≈ `103` بت → التصنيف: **ممتازة**
- مثال ناتج (عشوائي، يختلف كل مرة): `q7$Km2!vP9xL#4nZ`

**English:** Length `16` with all four sets enabled (pool ≈ 85 chars) →
- Entropy ≈ `16 × log2(85)` ≈ `103` bits → rating: **excellent**
- Example output (random, differs each time): `q7$Km2!vP9xL#4nZ`

## ملاحظات وقيود · Notes & limitations
**بالعربي:** يستخدم مولّد النظام الآمن تشفيرياً — الكلمات لا تُحفظ ولا تُرسل لأي خادم. إذا عُطّلت كل المجموعات يكون الناتج فارغاً. تقدير الإنتروبيا افتراضي يفترض عشوائية موحّدة عبر كامل المجموعة.
**English:** Uses the cryptographically secure system RNG — passwords are neither stored nor sent to any server. If all sets are disabled the output is empty. The entropy estimate assumes uniform randomness across the full pool.
