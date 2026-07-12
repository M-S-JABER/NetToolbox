# QR Code Generator · مولّد رموز QR

> **Category / التصنيف:** Calculators / الحاسبات  
> **Tool ID:** `qr-generator`

---

## نظرة عامة · Overview
**بالعربي:** أداة تحوّل أي نص أو رابط أو بيانات إلى رمز `QR` واضح يظهر مباشرة على الشاشة. تكتب النص فيتولّد الرمز فوراً، جاهزاً للمسح بأي كاميرا. مفيدة لمشاركة الروابط، بيانات Wi-Fi، أو أي نص قصير بسرعة.
**English:** A tool that turns any text, URL, or data into a crisp `QR` code shown directly on screen. You type the text and the code is generated instantly, ready to scan with any camera. Handy for sharing links, Wi-Fi details, or any short text quickly.

## كيف تعمل · How it works
**بالعربي:** التوليد في `QRCode.image` عبر مرشّح CoreImage المدمج `CIQRCodeGenerator` — **يعمل محلياً بالكامل بدون اتصال بالإنترنت**. يُحوَّل النص إلى بيانات UTF-8، ثم يُبنى الرمز بمستوى تصحيح أخطاء متوسط (`M`)، ويُكبَّر بعامل ×12 مع تعطيل التنعيم (interpolation) لحواف حادة، ثم يُرسم كصورة `UIImage` على خلفية بيضاء. يعتمد على `CoreImage` و`UIKit` من Apple فقط.
**English:** Generation happens in `QRCode.image` via Apple's built-in CoreImage filter `CIQRCodeGenerator` — **runs 100% on-device, no network**. The text is converted to UTF-8 data, the code is built with medium error-correction level (`M`), scaled ×12 with interpolation disabled for sharp edges, then rendered as a `UIImage` on a white background. Relies on Apple's `CoreImage` and `UIKit` only.

## المدخلات · Inputs
| Field · الحقل | الوصف · Description |
|---|---|
| `text` | النص أو الرابط أو البيانات المراد ترميزها (متعدد الأسطر مدعوم). The text, URL, or data to encode (multiline supported). |

## المخرجات · Outputs
**بالعربي:** صورة رمز `QR` تظهر على خلفية بيضاء بحواف حادة، بعرض حتى 260 نقطة. تُحدَّث فوراً مع تغيّر النص، ويمكن التقاطها بلقطة شاشة أو مسحها مباشرة.
**English:** A `QR` code image on a white background with sharp edges, up to 260 points wide. It updates instantly as the text changes and can be screenshotted or scanned directly.

## مثال تشغيل · Worked example
**بالعربي:** إدخال `https://aswaralmudun.com` → يظهر رمز QR فور الكتابة؛ عند مسحه بكاميرا الهاتف يفتح الرابط نفسه. النص الفارغ لا يُنتج أي رمز.
**English:** Input `https://aswaralmudun.com` → a QR code appears as you type; scanning it with a phone camera opens that same URL. Empty text produces no code.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** مستوى تصحيح الأخطاء ثابت عند `M` (متوسط). لا يوجد خيار حفظ/تصدير مدمج للصورة سوى لقطة الشاشة. متاح على منصات UIKit (iOS) فقط. النصوص الطويلة جداً قد تُنتج رموزاً كثيفة يصعب مسحها. كل شيء محلي — لا يُرسل النص لأي خادم.
**English:** The error-correction level is fixed at `M` (medium). There is no built-in save/export beyond a screenshot. Available on UIKit platforms (iOS) only. Very long text yields dense codes that can be hard to scan. Everything is local — the text is never sent to any server.
