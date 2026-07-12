# JSON Formatter · مُنسِّق JSON

> **Category / التصنيف:** Calculators / الحاسبات  
> **Tool ID:** `json-formatter`

---

## نظرة عامة · Overview
**بالعربي:** أداة تتحقق من صحة نص JSON وتُعيد تنسيقه: إمّا بطباعة جميلة (pretty-print) مع مسافات بادئة، أو بضغطه (minify) في سطر واحد. تُرتّب المفاتيح أبجدياً في الحالتين. تعمل محلياً بالكامل بدون إنترنت.  
**English:** Validates a JSON string and re-formats it: either pretty-printed with indentation, or minified onto one line. Keys are sorted alphabetically in both modes. Runs 100% on-device with no network.

## كيف تعمل · How it works
**بالعربي:** يُحوَّل النص إلى بايتات UTF-8 ثم يُحلَّل عبر `JSONSerialization.jsonObject` مع خيار `.fragmentsAllowed` (فيقبل القيم المفردة مثل رقم أو سلسلة، لا كائناً/مصفوفة فقط). عند نجاح التحليل يُعاد الإخراج عبر `JSONSerialization.data`: في وضع الضغط بخيارات `[.sortedKeys, .fragmentsAllowed, .withoutEscapingSlashes]`، وفي وضع التنسيق تُضاف `.prettyPrinted`. `sortedKeys` يرتّب المفاتيح أبجدياً و`withoutEscapingSlashes` يمنع تهريب `/`. أي خطأ في التحليل يُعرَض بوصفه المحلّي (localizedDescription). كل شيء عبر مُحلّل Foundation محلياً.  
**English:** The text is converted to UTF-8 bytes and parsed via `JSONSerialization.jsonObject` with `.fragmentsAllowed` (so single values like a number or string are accepted, not only objects/arrays). On success the output is re-serialized via `JSONSerialization.data`: in minify mode with options `[.sortedKeys, .fragmentsAllowed, .withoutEscapingSlashes]`, and in pretty mode `.prettyPrinted` is added. `sortedKeys` alphabetizes keys and `withoutEscapingSlashes` avoids escaping `/`. Any parse error is shown via its localizedDescription. Everything runs locally through Foundation's parser.

## المدخلات · Inputs
**بالعربي:**
- `Input` — نص JSON (يقبل عدة أسطر). بدون تصحيح تلقائي.
- `Minify` — مفتاح تبديل: مُفعَّل = ضغط في سطر واحد، مُطفأ = طباعة جميلة بمسافات بادئة.

**English:**
- `Input` — the JSON text (multi-line). Autocorrection disabled.
- `Minify` — a toggle: on = minified onto one line, off = pretty-printed with indentation.

## المخرجات · Outputs
**بالعربي:** عند صحة الإدخال: نص JSON المُنسَّق (بمفاتيح مرتّبة) قابل للتحديد والنسخ. عند وجود خطأ: بطاقة خطأ تعرض سبب فشل التحليل. يظهر الإخراج بخط أحادي المسافة ومن اليسار لليمين.  
**English:** On valid input: the formatted JSON (with sorted keys), selectable and copyable. On error: an error card showing why parsing failed. Output is monospace and left-to-right.

## مثال تشغيل · Worked example
**بالعربي:** إدخال `{"b":1,"a":2}` مع إطفاء Minify يُنتج:
```
{
  "a" : 2,
  "b" : 1
}
```
ومع تفعيل Minify يُنتج `{"a":2,"b":1}` (لاحظ ترتيب المفاتيح أبجدياً).  
**English:** Input `{"b":1,"a":2}` with Minify off yields:
```
{
  "a" : 2,
  "b" : 1
}
```
With Minify on it yields `{"a":2,"b":1}` (note the alphabetical key order).

## ملاحظات وقيود · Notes & limitations
**بالعربي:** يُعيد التنسيق دائماً يرتّب المفاتيح، لذا لا يُحافَظ على ترتيبها الأصلي. القيم المفردة (fragments) مقبولة. الأرقام قد يُعاد تمثيلها بصيغة Foundation القياسية. لا اتصال بالشبكة إطلاقاً — كل التحليل والتنسيق محلي على الجهاز.  
**English:** Re-formatting always sorts keys, so the original key order is not preserved. Single-value fragments are accepted. Numbers may be re-rendered in Foundation's canonical form. No network access at all — all parsing and formatting is local on-device.
