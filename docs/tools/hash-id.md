# Hash Identifier · مُعرِّف نوع التجزئة

> **Category / التصنيف:** Calculators / الحاسبات  
> **Tool ID:** `hash-id`

---

## نظرة عامة · Overview
**بالعربي:** أداة تُخمّن الخوارزمية (أو الخوارزميات) التي على الأرجح أنتجت سلسلة تجزئة (hash) معيّنة، بالاعتماد على طولها ومجموعة الأحرف فيها والبادئة (prefix) إن وُجدت. لا تفكّ التجزئة ولا تتحقق منها؛ هي مجرد استدلال (heuristic). تعمل محلياً بالكامل بدون إنترنت.  
**English:** Guesses the likely algorithm(s) that produced a given hash string based on its length, character set, and any leading prefix. It does not crack or verify the hash; it is pure heuristic identification. Runs 100% on-device with no network.

## كيف تعمل · How it works
**بالعربي:** تُقتطع المسافات، ثم يُفحص المدخل على ثلاث مراحل: (1) البوادئ الخاصة بصيغ التخزين المُعياري (modular crypt): `$2a$`/`$2b$`/`$2y$` = bcrypt، `$1$` = md5crypt، `$5$` = sha256crypt، `$6$` = sha512crypt، `$apr1$` = Apache apr1-md5، `$argon2` = Argon2، `$pbkdf2` = PBKDF2، `{SSHA}` = Salted SHA-1 (LDAP)، `{SHA}` = SHA-1 (LDAP). (2) إن كانت السلسلة كلها أرقاماً ست عشرية (hex) يُستدل بالطول: 32 → MD5/NTLM/MD4/LM، 40 → SHA-1/RIPEMD-160، 56 → SHA-224/SHA3-224، 64 → SHA-256/SHA3-256/BLAKE2s، 96 → SHA-384/SHA3-384، 128 → SHA-512/SHA3-512/BLAKE2b/Whirlpool، 16 → CRC-64/MySQL 3.23، 8 → CRC-32/Adler-32. (3) إن بدت السلسلة بترميز base64: طول 24 وتنتهي بـ `==` → MD5 (base64)، طول 28 وتنتهي بـ `=` → SHA-1 (base64)، طول 44 وتنتهي بـ `=` → SHA-256 (base64). كل ذلك منطق نصي محض داخل Swift دون أي مكتبة تشفير.  
**English:** Whitespace is trimmed, then the input is checked in three stages: (1) modular-crypt prefixes — `$2a$`/`$2b$`/`$2y$` = bcrypt, `$1$` = md5crypt, `$5$` = sha256crypt, `$6$` = sha512crypt, `$apr1$` = Apache apr1-md5, `$argon2` = Argon2, `$pbkdf2` = PBKDF2, `{SSHA}` = Salted SHA-1 (LDAP), `{SHA}` = SHA-1 (LDAP). (2) If the string is all hex digits, the length maps to candidates: 32 → MD5/NTLM/MD4/LM, 40 → SHA-1/RIPEMD-160, 56 → SHA-224/SHA3-224, 64 → SHA-256/SHA3-256/BLAKE2s, 96 → SHA-384/SHA3-384, 128 → SHA-512/SHA3-512/BLAKE2b/Whirlpool, 16 → CRC-64/MySQL 3.23, 8 → CRC-32/Adler-32. (3) If it looks base64: length 24 ending in `==` → MD5 (base64), length 28 ending in `=` → SHA-1 (base64), length 44 ending in `=` → SHA-256 (base64). This is plain string logic in Swift with no crypto library.

## المدخلات · Inputs
**بالعربي:**
- `Hash` — سلسلة التجزئة المراد التعرّف عليها. حقل نصي واحد (يقبل حتى 4 أسطر)، بدون تصحيح تلقائي ولا كتابة كبيرة، ويُعرض بترتيب من اليسار لليمين.

**English:**
- `Hash` — the hash string to identify. A single text field (up to 4 lines), autocorrection and autocapitalization disabled, displayed left-to-right.

## المخرجات · Outputs
**بالعربي:** قائمة بأسماء الخوارزميات المرشّحة، مرتّبة كما وردت في الجدول. إذا لم يطابق المدخل أي نمط تظهر رسالة بعدم وجود مرشّحين. المخرجات مجرد احتمالات وليست تأكيداً قاطعاً.  
**English:** A list of candidate algorithm names, in the order defined by the table. If the input matches no pattern, a "no candidates" message is shown. Results are possibilities, not a definitive identification.

## مثال تشغيل · Worked example
**بالعربي:** إدخال `5d41402abc4b2a76b9719d911017c592` (32 حرفاً ست عشرياً) يُنتج المرشحين: `MD5`، `NTLM`، `MD4`، `LM`. وإدخال `$2y$10$N9qo8uLOickgx2ZMRZoM1e...` يُنتج `bcrypt` مباشرة.  
**English:** Input `5d41402abc4b2a76b9719d911017c592` (32 hex chars) yields candidates: `MD5`, `NTLM`, `MD4`, `LM`. Input `$2y$10$N9qo8uLOickgx2ZMRZoM1e...` yields `bcrypt` directly.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** التعرّف استدلالي بالطول والشكل فقط؛ خوارزميات مختلفة قد تشترك في الطول نفسه (مثل MD5 وNTLM بطول 32)، لذا لا يمكن الجزم بخوارزمية واحدة من الطول وحده. لا تُرسَل أي بيانات إلى أي خادم — كل الحساب محلي. سلاسل غير الست عشرية وغير base64 المعروفة لن تُطابَق.  
**English:** Identification is heuristic by length and shape only; different algorithms share the same length (e.g. MD5 and NTLM at 32), so a single algorithm cannot be confirmed from length alone. No data leaves the device — all computation is local. Non-hex strings that are not recognized base64 forms will not match.
