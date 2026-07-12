# Regex Tester · مُختبِر التعابير النمطية

> **Category / التصنيف:** Calculators / الحاسبات  
> **Tool ID:** `regex`

---

## نظرة عامة · Overview
**بالعربي:** أداة تختبر تعبيراً نمطياً (regular expression) على نص، وتُظهر كل المطابقات مع المجموعات الملتقطة (capture groups) في كل مطابقة. تدعم وضع تجاهل حالة الأحرف. تعمل محلياً بالكامل بدون إنترنت.  
**English:** Tests a regular expression against a string and shows every match along with the capture groups in each match. Supports a case-insensitive mode. Runs 100% on-device with no network.

## كيف تعمل · How it works
**بالعربي:** يُبنى `NSRegularExpression` من النمط المُدخَل؛ إذا كان النمط غير صالح تظهر رسالة خطأ. عند تفعيل خيار تجاهل الحالة تُضاف خيار `.caseInsensitive`. يُمرَّر النص كـ `NSString` ويُبحَث في كامل مداه عبر `enumerateMatches`. لكل مطابقة يُستخرَج النص الكامل المطابِق، ثم إن كان عدد المدايات أكبر من 1 تُستخرَج المجموعات الملتقطة (من الفهرس 1 فصاعداً)؛ المجموعة غير المُطابِقة (موقعها `NSNotFound`) تُمثَّل بسلسلة فارغة. المنطق محلي بالكامل عبر محرّك التعابير النمطية في Foundation (ICU).  
**English:** An `NSRegularExpression` is built from the pattern; if the pattern is invalid, an error message is shown. When case-insensitive is enabled, the `.caseInsensitive` option is added. The text is passed as an `NSString` and searched over its full range via `enumerateMatches`. For each match, the full matched text is extracted, then if the number of ranges is greater than 1 the capture groups (index 1 onward) are extracted; a non-matching group (location `NSNotFound`) is represented by an empty string. All logic is local via Foundation's regex engine (ICU).

## المدخلات · Inputs
**بالعربي:**
- `Pattern` — التعبير النمطي (صيغة ICU/NSRegularExpression). سطر واحد، بدون تصحيح تلقائي.
- `Text` — النص المراد البحث فيه (عدة أسطر).
- `Case insensitive` — مفتاح تبديل لتجاهل حالة الأحرف.

**English:**
- `Pattern` — the regular expression (ICU/NSRegularExpression syntax). Single line, autocorrection disabled.
- `Text` — the text to search in (multi-line).
- `Case insensitive` — a toggle to ignore letter case.

## المخرجات · Outputs
**بالعربي:** عدد المطابقات، ثم لكل مطابقة نصّها الكامل (بلون التمييز) وتحته المجموعات الملتقطة بصيغة `$1=...  $2=...`. إذا لا مطابقات تظهر رسالة "لا مطابقات"، وإذا كان النمط غير صالح تظهر بطاقة خطأ.  
**English:** The match count, then for each match its full text (accent-colored) with the capture groups below it as `$1=...  $2=...`. If there are no matches, a "no match" message appears; if the pattern is invalid, an error card appears.

## مثال تشغيل · Worked example
**بالعربي:** النمط `(\d{4})-(\d{2})` على النص `الإصدار 2026-07 والتحديث 2025-11` يُنتج مطابقتين: `2026-07` بمجموعات `$1=2026  $2=07`، و`2025-11` بمجموعات `$1=2025  $2=11`.  
**English:** Pattern `(\d{4})-(\d{2})` on text `release 2026-07 and update 2025-11` yields two matches: `2026-07` with groups `$1=2026  $2=07`, and `2025-11` with groups `$1=2025  $2=11`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** الصيغة المدعومة هي صيغة ICU الخاصة بـ `NSRegularExpression`، وقد تختلف عن PCRE أو صيغة لغات أخرى في بعض التفاصيل. المطابقة على مدايات UTF-16 (`NSString`)، ما قد يؤثّر في عدّ المواقع مع الرموز خارج النطاق الأساسي. نمط فارغ لا يُنتج مطابقات. لا اتصال بالشبكة إطلاقاً.  
**English:** The supported syntax is ICU's `NSRegularExpression` flavor, which may differ from PCRE or other languages in some details. Matching is over UTF-16 ranges (`NSString`), which can affect index counting with characters outside the basic plane. An empty pattern produces no matches. No network access at all.
