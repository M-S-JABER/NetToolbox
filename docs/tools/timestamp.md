# Timestamp Converter · محوّل الطوابع الزمنية

> **Category / التصنيف:** Calculators / الحاسبات  
> **Tool ID:** `timestamp`

---

## نظرة عامة · Overview
**بالعربي:** أداة تحويل ثنائية الاتجاه بين طابع Unix الزمني (عدد الثواني أو الميلي ثانية منذ 1970) والتاريخ المقروء للإنسان. تُظهر الوقت بصيغ UTC والمحلي وISO 8601، وتُخرج الطابع الزمني من تاريخ تختاره. تعمل محلياً بالكامل بدون إنترنت.  
**English:** A two-way converter between a Unix timestamp (seconds or milliseconds since 1970) and a human-readable date. It shows the time in UTC, local, and ISO 8601 forms, and produces a timestamp from a date you pick. Runs 100% on-device with no network.

## كيف تعمل · How it works
**بالعربي:** في الاتجاه الأول (من الطابع إلى التاريخ) يُحوَّل النص إلى رقم عشري (Double)؛ إذا تجاوزت قيمته المطلقة `1,000,000,000,000` يُفترَض أنها ميلي ثانية فتُقسَم على 1000، وإلا فهي ثوانٍ. ثم يُبنى `Date(timeIntervalSince1970:)`. تُنسَّق النتيجة بثلاث صيغ: UTC عبر `DateFormatter` بلوكيل `en_US_POSIX` ومنطقة `UTC` بنمط `yyyy-MM-dd HH:mm:ss 'UTC'`؛ والمحلي عبر تنسيق النظام؛ وISO 8601 عبر `ISO8601DateFormatter` بخيار `.withInternetDateTime`. في الاتجاه الثاني (من التاريخ إلى الطابع) تختار تاريخاً عبر `DatePicker` فتُعرض قيمته بالثواني وبالميلي ثانية. كل شيء عبر Foundation محلياً.  
**English:** In the first direction (timestamp → date), the text is parsed to a Double; if its absolute value exceeds `1,000,000,000,000` it is assumed to be milliseconds and divided by 1000, otherwise seconds. A `Date(timeIntervalSince1970:)` is then built. The result is formatted three ways: UTC via `DateFormatter` with locale `en_US_POSIX`, timezone `UTC`, pattern `yyyy-MM-dd HH:mm:ss 'UTC'`; local via system formatting; and ISO 8601 via `ISO8601DateFormatter` with `.withInternetDateTime`. In the second direction (date → timestamp), you pick a date with a `DatePicker` and its value is shown in seconds and milliseconds. Everything runs locally through Foundation.

## المدخلات · Inputs
**بالعربي:**
- `Epoch` — نص رقمي يمثّل الطابع الزمني (ثوانٍ أو ميلي ثانية، يُكتشَف تلقائياً). زر `Now` يملؤه بالوقت الحالي بالثواني.
- `Pick` — منتقي تاريخ ووقت لتحويل الاتجاه المعاكس.

**English:**
- `Epoch` — numeric text of the timestamp (seconds or milliseconds, auto-detected). A `Now` button fills it with the current time in seconds.
- `Pick` — a date/time picker for the reverse conversion.

## المخرجات · Outputs
**بالعربي:** من الطابع: `UTC` بصيغة `yyyy-MM-dd HH:mm:ss UTC`، و`Local` بصيغة النظام، و`ISO 8601`. من التاريخ المُختار: الطابع بالثواني والطابع بالميلي ثانية. جميعها قابلة للنسخ. مدخل غير رقمي يُظهر رسالة خطأ.  
**English:** From the timestamp: `UTC` as `yyyy-MM-dd HH:mm:ss UTC`, `Local` in system format, and `ISO 8601`. From the picked date: the timestamp in seconds and in milliseconds. All are copyable. A non-numeric input shows an error message.

## مثال تشغيل · Worked example
**بالعربي:** إدخال `1700000000` يعطي UTC = `2023-11-14 22:13:20 UTC` وISO = `2023-11-14T22:13:20Z`. وإدخال `1700000000000` (ميلي ثانية) يُكتشَف ويُقسَم على 1000 فيعطي التاريخ نفسه.  
**English:** Input `1700000000` gives UTC = `2023-11-14 22:13:20 UTC` and ISO = `2023-11-14T22:13:20Z`. Input `1700000000000` (milliseconds) is detected, divided by 1000, and yields the same date.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** كشف الثواني/الميلي ثانية عتبته `1,000,000,000,000`؛ القيم الكبيرة جداً تُعامَل كميلي ثانية دائماً. زر `Now` يكتب الثواني فقط. الصيغة المحلية تتبع منطقة الجهاز ولغته. لا اتصال بالشبكة إطلاقاً.  
**English:** The seconds/milliseconds detection threshold is `1,000,000,000,000`; very large values are always treated as milliseconds. The `Now` button writes seconds only. The local format follows the device's timezone and locale. No network access at all.
