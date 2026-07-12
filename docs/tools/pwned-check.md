# Pwned Password Check · فحص كلمة المرور المُخترَقة

> **Category / التصنيف:** Security / الأمان  
> **Tool ID:** `pwned-check`

---

## نظرة عامة · Overview
**بالعربي:** أداة تتحقّق مما إذا كانت كلمة مرور قد ظهرت في تسريبات بيانات معروفة، باستخدام خدمة Have I Been Pwned. تستخدم نموذج **k-anonymity** (إخفاء الهوية الجزئي): لا تُرسَل كلمة المرور ولا بصمتها الكاملة إلى الخادم أبدًا — فقط أول 5 خانات من بصمة SHA-1.

**English:** Checks whether a password has appeared in known data breaches, using the Have I Been Pwned service. It uses the **k-anonymity** model: neither the password nor its full hash is ever sent to the server — only the first 5 hex characters of the SHA-1 hash.

## كيف تعمل · How it works
**بالعربي:** تُحسَب بصمة `SHA-1` لكلمة المرور محليًا عبر `CryptoKit` وتُحوَّل لست عشري بأحرف كبيرة. تُقسَم إلى بادئة (أول 5 خانات) ولاحقة (الباقي). تُرسَل البادئة فقط في طلب `GET` إلى `https://api.pwnedpasswords.com/range/<prefix>` (المنفذ `443`) مع الترويسة `Add-Padding: true` (لإخفاء حجم الرد)، ومهلة `12` ثانية عبر `URLSession` بإعداد `ephemeral`. يعيد الخادم قائمة بكل اللواحق التي تشترك في نفس البادئة مع عدد مرات ظهورها. تبحث الأداة محليًا عن اللاحقة المطابِقة وتقرأ عدّاد الاختراق. اللاحقة الكاملة لا تغادر الجهاز.

**English:** The password's `SHA-1` hash is computed locally via `CryptoKit` and rendered as uppercase hex. It is split into a prefix (first 5 chars) and a suffix (the rest). Only the prefix is sent in a `GET` request to `https://api.pwnedpasswords.com/range/<prefix>` (port `443`) with the `Add-Padding: true` header (to obscure the response size), a `12`-second timeout over an `ephemeral` `URLSession`. The server returns a list of all suffixes sharing that prefix with their breach counts. The tool locally matches the suffix and reads the breach count. The full suffix never leaves the device.

## المدخلات · Inputs
- **Password / كلمة المرور:** كلمة المرور المراد فحصها (حقل آمن مع خيار إظهار/إخفاء) · the password to check (secure field with a reveal toggle).

## المخرجات · Outputs
**بالعربي:** نتيجة واحدة من:
- **آمنة (`safe`):** شارة خضراء ورسالة بأن كلمة المرور لم تظهر في أي تسريب معروف (العدّاد `0`).
- **مُخترَقة (`pwned`):** شارة حمراء وعدد المرات التي ظهرت فيها كلمة المرور في التسريبات.
- **خطأ:** رسالة عند فشل الاتصال أو حالة HTTP غير ناجحة.

**English:** A single result of:
- **Safe (`safe`):** a green badge and a message that the password does not appear in any known breach (count `0`).
- **Pwned (`pwned`):** a red badge and the number of times the password appears in breaches.
- **Error:** a message on connection failure or a non-2xx HTTP status.

## مثال تشغيل · Worked example
**بالعربي:** إدخال كلمة المرور الشائعة `password`. بصمة SHA-1 تبدأ بـ `5BAA6`؛ تُرسَل هذه البادئة فقط، وتُطابَق اللاحقة `1E4C9B93F3F0682250B6CF8331B7EE68FD8` محليًا، فيظهر أنها مُخترَقة بعدد كبير جدًا من المرات (بالملايين). مقابل ذلك، كلمة مرور عشوائية قوية ستظهر `safe`.

**English:** Enter the common password `password`. Its SHA-1 hash begins with `5BAA6`; only that prefix is sent, and the suffix `1E4C9B93F3F0682250B6CF8331B7EE68FD8` is matched locally, revealing it is pwned an enormous number of times (millions). A strong random password would instead show `safe`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** بفضل k-anonymity، يرى خادم HIBP أول 5 خانات فقط من البصمة ولا يمكنه استنتاج كلمة المرور. يتطلّب اتصالاً بالإنترنت. الحقل آمن افتراضيًا؛ ومع ذلك يُفضّل ألا تُدخِل كلمة مرور حقيقية قيد الاستخدام إلا للتحقّق. «آمنة» تعني فقط عدم الظهور في التسريبات، لا أنها قوية بحد ذاتها.

**English:** Thanks to k-anonymity, the HIBP server sees only the first 5 hex chars of the hash and cannot infer the password. Requires an internet connection. The field is secure by default; still, prefer not to enter a real in-use password except to verify it. "Safe" means only that it has not appeared in breaches, not that it is inherently strong.
