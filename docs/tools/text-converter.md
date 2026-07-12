# Text Encoder / Decoder · محوّل النصوص (ترميز وفكّ ترميز)

> **Category / التصنيف:** Calculators / الحاسبات  
> **Tool ID:** `text-converter`

---

## نظرة عامة · Overview
**بالعربي:** أداة ترميز وفكّ ترميز النصوص عبر ثلاث صيغ شائعة: `Base64` و`Hex` و`URL` (percent-encoding). تختار العملية من قائمة، تكتب النص، فيظهر الناتج فوراً مع زر نسخ. مفيدة للمطوّرين عند التعامل مع الرموز (tokens)، وترويسات HTTP، وسلاسل الاستعلام.
**English:** A tool for encoding and decoding text via three common schemes: `Base64`, `Hex`, and `URL` (percent-encoding). You pick an operation from a menu, type the text, and the output appears instantly with a copy button. Useful for developers dealing with tokens, HTTP headers, and query strings.

## كيف تعمل · How it works
**بالعربي:** المنطق في `TextConverter.apply` وهو تحويل صرف — **يعمل محلياً بالكامل بدون اتصال بالإنترنت**. العمليات المتاحة: ترميز/فكّ Base64 (عبر `Data.base64EncodedString` و`Data(base64Encoded:)`)، ترميز/فكّ Hex (كل بايت بخانتين hex؛ الفكّ يتجاهل المسافات و`:` والبادئة `0x`)، وترميز/فكّ URL (percent-encoding بالسماح للأحرف الأبجدية الرقمية فقط عند الترميز، عبر `addingPercentEncoding` و`removingPercentEncoding`). كل النصوص تُعامَل بترميز UTF-8، وأي بايت لا يشكّل UTF-8 صالحاً عند الفكّ يُنتج خطأ. يعتمد على `Foundation` فقط.
**English:** Logic lives in `TextConverter.apply`, a pure transform — **runs 100% on-device, no network**. Operations: Base64 encode/decode (via `Data.base64EncodedString` and `Data(base64Encoded:)`), Hex encode/decode (each byte as two hex digits; decoding ignores spaces, `:`, and a leading `0x`), and URL encode/decode (percent-encoding allowing only alphanumerics on encode, via `addingPercentEncoding` and `removingPercentEncoding`). All text is treated as UTF-8; any byte that isn't valid UTF-8 on decode produces an error. Depends on `Foundation` only.

## المدخلات · Inputs
| Field · الحقل | الوصف · Description |
|---|---|
| `operation` | العملية: `base64Encode` / `base64Decode` / `hexEncode` / `hexDecode` / `urlEncode` / `urlDecode`. The chosen operation. |
| `input` | النص المراد تحويله (متعدد الأسطر مدعوم). The text to transform (multiline supported). |

## المخرجات · Outputs
**بالعربي:** نصّ الناتج، قابل للتحديد والنسخ عبر زر النسخ. عند فشل الفكّ (Base64 غير صالح، Hex بطول فردي أو أحرف غير hex، أو ناتج ليس UTF-8) تظهر رسالة خطأ مناسبة.
**English:** The output text, selectable and copyable via a copy button. If decoding fails (invalid Base64, odd-length or non-hex string, or non-UTF-8 result) an appropriate error message appears.

## مثال تشغيل · Worked example
**بالعربي:**
- `base64Encode` لـ `Hello` → `SGVsbG8=`
- `hexEncode` لـ `Hi` → `4869`
- `urlEncode` لـ `a b&c` → `a%20b%26c`
- `base64Decode` لـ `SGVsbG8=` → `Hello`

**English:**
- `base64Encode` of `Hello` → `SGVsbG8=`
- `hexEncode` of `Hi` → `4869`
- `urlEncode` of `a b&c` → `a%20b%26c`
- `base64Decode` of `SGVsbG8=` → `Hello`

## ملاحظات وقيود · Notes & limitations
**بالعربي:** ترميز URL يُرمّز كل ما ليس حرفاً أبجدياً رقمياً (بما فيه المسافة إلى `%20`)، وهو أكثر تحفظاً من ترميز مكوّنات الرابط القياسي. المدخلات والمخرجات تبقى على الجهاز — لا اتصال بالإنترنت.
**English:** URL encode percent-encodes everything that isn't alphanumeric (including spaces to `%20`), which is more conservative than standard URL-component encoding. Inputs and outputs stay on-device — no internet access.
