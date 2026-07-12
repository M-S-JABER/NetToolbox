# Random Generators · مُولِّدات عشوائية

> **Category / التصنيف:** Calculators / الحاسبات  
> **Tool ID:** `generators`

---

## نظرة عامة · Overview
**بالعربي:** أداة تُولّد مُعرِّفات عشوائية جاهزة للاستخدام: معرّف UUIDv4، وعنوان MAC محلي الإدارة (locally administered)، وسلسلة ست عشرية (hex) عشوائية بطول تختاره. مفيدة للاختبار والإعداد وتوليد قيم فريدة. تعمل محلياً بالكامل بدون إنترنت.  
**English:** Generates ready-to-use random identifiers: a UUIDv4, a locally administered MAC address, and a random hex string of a length you choose. Useful for testing, provisioning, and generating unique values. Runs 100% on-device with no network.

## كيف تعمل · How it works
**بالعربي:**
- **UUID:** يُستخدَم `UUID()` من Foundation الذي يُنتج UUID من الإصدار الرابع (v4، عشوائي).
- **MAC:** تُولَّد 6 بايتات عشوائية، ثم يُضبَط البايت الأول ليكون محلي الإدارة وأحادي البث (unicast) عبر `(byte | 0x02) & 0xFE` — أي تُشعَل خانة locally administered وتُطفَأ خانة multicast. يُنسَّق بصيغة `XX:XX:XX:XX:XX:XX` بأحرف كبيرة.
- **Hex:** تُولَّد `count` بايتاً عشوائياً (محصوراً بين 1 و256) وتُطبَع كسلسلة ست عشرية بأحرف صغيرة؛ كل بايت خانتان، فالطول النهائي = `count × 2` خانة.

كل التوليد يعتمد على `UInt8.random` و`UUID()` محلياً دون أي شبكة. تحتفظ الأداة بآخر 20 عنصراً لكل من UUID وMAC.  
**English:**
- **UUID:** Uses Foundation's `UUID()`, which produces a version-4 (random) UUID.
- **MAC:** Six random bytes are generated, then the first byte is forced to locally administered and unicast via `(byte | 0x02) & 0xFE` — setting the locally-administered bit and clearing the multicast bit. Formatted as `XX:XX:XX:XX:XX:XX` uppercase.
- **Hex:** `count` random bytes (clamped to 1–256) are generated and printed as a lowercase hex string; each byte is two hex digits, so the final length is `count × 2` characters.

All generation uses `UInt8.random` and `UUID()` locally with no network. The tool keeps the last 20 items each for UUID and MAC.

## المدخلات · Inputs
**بالعربي:**
- زر توليد UUID — يُضيف معرّفاً جديداً لأعلى القائمة.
- زر توليد MAC — يُضيف عنواناً جديداً لأعلى القائمة.
- `Hex length` — عدد البايتات المطلوبة (الافتراضي `16`)؛ يُقصَر فعلياً بين 1 و256. زر التوليد يُنتج السلسلة.

**English:**
- Generate UUID button — prepends a new identifier to the list.
- Generate MAC button — prepends a new address to the list.
- `Hex length` — the number of bytes desired (default `16`); effectively clamped to 1–256. A generate button produces the string.

## المخرجات · Outputs
**بالعربي:** قوائم قابلة للنسخ من UUIDs وMACs (آخر 20 لكل نوع)، وسلسلة hex عشوائية واحدة قابلة للنسخ. جميع القيم بخط أحادي المسافة.  
**English:** Copyable lists of UUIDs and MACs (last 20 of each), and a single copyable random hex string. All values are shown in monospace.

## مثال تشغيل · Worked example
**بالعربي:** توليد UUID قد يعطي `9b2e1c7a-4f3d-4a1b-8c2e-1d5f6a7b8c9d`. توليد MAC قد يعطي `A2:3F:1B:9C:44:D0` (البايت الأول دائماً محلي الإدارة). طول hex = `16` يُنتج 32 خانة مثل `3f9a1c04be77d21e5a6b0c8f4e12ab90`.  
**English:** A UUID might be `9b2e1c7a-4f3d-4a1b-8c2e-1d5f6a7b8c9d`. A MAC might be `A2:3F:1B:9C:44:D0` (first byte always locally administered). Hex length `16` yields 32 characters such as `3f9a1c04be77d21e5a6b0c8f4e12ab90`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** يعتمد التوليد على مُولّد Swift العشوائي القياسي؛ مناسب للاختبار والمعرّفات العامة، وليس مضموناً كمصدر تشفيري قوي لأغراض أمنية حسّاسة. طول hex محصور بين 1 و256 بايت. تُحتفَظ آخر 20 نتيجة فقط لكل قائمة. لا اتصال بالشبكة إطلاقاً.  
**English:** Generation uses Swift's standard random generator; suitable for testing and general identifiers, but not guaranteed as a strong cryptographic source for security-sensitive purposes. Hex length is clamped to 1–256 bytes. Only the last 20 results are kept per list. No network access at all.
