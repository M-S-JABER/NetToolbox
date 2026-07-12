# Crypto Toolbox (Hashes & JWT) · صندوق أدوات التشفير (البصمات و JWT)

> **Category / التصنيف:** Calculators / الحاسبات  
> **Tool ID:** `crypto-tools`

---

## نظرة عامة · Overview
**بالعربي:** أداة تجمع وظيفتين تشفيريتين: (1) حساب بصمات (hashes) متعددة لأي نص — MD5، SHA-1، SHA-256، SHA-384، SHA-512؛ و(2) فكّ وعرض محتوى رمز `JWT` (الترويسة والحمولة) بصيغة JSON منسّقة مع كشف الخوارزمية وتاريخ الانتهاء. مفيدة للمطوّرين للتحقق السريع من التكاملية وفحص الرموز.
**English:** A tool bundling two cryptographic functions: (1) computing multiple hashes of any text — MD5, SHA-1, SHA-256, SHA-384, SHA-512; and (2) decoding and displaying a `JWT`'s contents (header and payload) as pretty JSON, with the algorithm and expiry detected. Useful for developers to quickly verify integrity and inspect tokens.

## كيف تعمل · How it works
**بالعربي:** المنطق في `CryptoTools` باستخدام `CryptoKit` و`Foundation` من Apple — **يعمل محلياً بالكامل بدون اتصال بالإنترنت**. **وضع البصمات:** يُحوَّل النص إلى بيانات UTF-8 وتُحسب البصمات الخمس دفعة واحدة وتُعرض كسلاسل hex (لاحظ أن MD5 وSHA-1 من `Insecure` لأنهما غير آمنتين تشفيرياً). **وضع JWT:** يُقسَّم الرمز على النقاط، ويُفكّ الجزءان الأول (الترويسة) والثاني (الحمولة) بترميز base64url ثم يُنسَّقان JSON بمفاتيح مرتّبة. يُقرأ الحقل `alg` من الترويسة و`exp` من الحمولة لتحديد الخوارزمية وحالة الانتهاء (منتهٍ/صالح) مقارنةً بالوقت الحالي. **لا يتم أي تحقق من توقيع JWT** — فحص وعرض فقط.
**English:** Logic lives in `CryptoTools` using Apple's `CryptoKit` and `Foundation` — **runs 100% on-device, no network**. **Hash mode:** the text becomes UTF-8 data and all five hashes are computed at once and shown as hex strings (note MD5 and SHA-1 come from `Insecure` as they are cryptographically broken). **JWT mode:** the token is split on dots; the first (header) and second (payload) parts are base64url-decoded then pretty-printed as JSON with sorted keys. The `alg` field is read from the header and `exp` from the payload to determine the algorithm and expiry state (expired/valid) versus the current time. **No JWT signature verification is performed** — decode and inspect only.

## المدخلات · Inputs
| Field · الحقل | الوصف · Description |
|---|---|
| `mode` | الوضع: `hash` (بصمات) أو `jwt` (فكّ رمز). Mode: hashes or JWT decode. |
| `input` | في وضع hash: أي نص. في وضع jwt: رمز JWT كامل (`header.payload.signature`). In hash mode: any text. In JWT mode: a full JWT. |

## المخرجات · Outputs
**بالعربي (hash):** خمس بصمات hex بأسماء `MD5`، `SHA-1`، `SHA-256`، `SHA-384`، `SHA-512`، كل واحدة قابلة للنسخ.
**بالعربي (jwt):** الخوارزمية (`alg`)، وشارة الصلاحية (صالح/منتهٍ) وتاريخ الانتهاء إن وُجد، ثم الترويسة والحمولة بصيغة JSON منسّقة. الرمز غير الصالح يُظهر رسالة خطأ.
**English (hash):** Five hex digests labeled `MD5`, `SHA-1`, `SHA-256`, `SHA-384`, `SHA-512`, each copyable.
**English (jwt):** The algorithm (`alg`), a validity badge (valid/expired) and expiry date if present, then the header and payload as pretty JSON. An invalid token shows an error.

## مثال تشغيل · Worked example
**بالعربي (hash):** النص `hello` →
- `MD5`: `5d41402abc4b2a76b9719d911017c592`
- `SHA-1`: `aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d`
- `SHA-256`: `2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824`

**بالعربي (jwt):** رمز مثل `eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMiLCJleHAiOjE3MDAwMDAwMDB9.xxxx` →
- الخوارزمية: `HS256` · الحالة: منتهٍ (لأن `exp` في الماضي) · الحمولة: `{ "exp": 1700000000, "sub": "123" }`

**English (hash):** Text `hello` →
- `MD5`: `5d41402abc4b2a76b9719d911017c592`
- `SHA-256`: `2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824`

**English (jwt):** A token like `eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMiLCJleHAiOjE3MDAwMDAwMDB9.xxxx` →
- Algorithm: `HS256` · Status: expired (`exp` is in the past) · Payload: `{ "exp": 1700000000, "sub": "123" }`

## ملاحظات وقيود · Notes & limitations
**بالعربي:** لا يُتحقق من توقيع الـ JWT إطلاقاً — لا يعني عرض الرمز أنه موثوق. MD5 وSHA-1 مُدرجتان للتوافق فقط ولا يُنصح بهما أمنياً. كل الحسابات على الجهاز — النصوص والرموز لا تُرسل لأي خادم، وهو مهم لأن الرموز قد تحمل بيانات حساسة.
**English:** JWT signatures are never verified — displaying a token does not mean it is trusted. MD5 and SHA-1 are included for compatibility only and are not recommended for security. All computation is on-device — text and tokens are never sent to any server, which matters since tokens may carry sensitive data.
