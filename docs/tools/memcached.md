# Memcached Stats · إحصاءات Memcached

> **Category / التصنيف:** Professional / احترافي  
> **Tool ID:** `memcached`

---

## نظرة عامة · Overview
**بالعربي:** أداة تتصل بخادم Memcached عبر بروتوكوله النصي على منفذ TCP رقم `11211` وتستعلم عن إصداره وإحصاءاته التشغيلية. تعرض المخرجات الخام كما يرسلها الخادم دون أي مصادقة، وهي مفيدة لفحص حالة الذاكرة المؤقتة ومعدل الإصابة (hit rate) وعدد الاتصالات.
**English:** Connects to a Memcached server over its plain-text protocol on TCP port `11211` and queries its version and runtime statistics. It shows the raw server output with no authentication, useful for inspecting cache health, hit rate, and connection counts.

## كيف تعمل · How it works
**بالعربي:** تفتح الأداة اتصال TCP إلى `host:port` (بمهلة فتح 6 ثوانٍ)، ثم ترسل سطرين نصيين: `version\r\n` متبوعاً بـ `stats\r\n`. بعدها تقرأ كل ما يرده الخادم (بمهلة 3 ثوانٍ) وتعرضه كنص UTF-8 خام. بروتوكول Memcached النصي يردّ بأسطر تبدأ بـ `STAT <اسم> <قيمة>` وتنتهي بـ `END`. لا توجد مصادقة ولا تشفير في هذا المسار.
**English:** The tool opens a TCP connection to `host:port` (6-second open timeout), then sends two text lines: `version\r\n` followed by `stats\r\n`. It reads everything the server returns (3-second receive timeout) and displays it as raw UTF-8 text. The Memcached text protocol replies with lines of the form `STAT <name> <value>` terminated by `END`. There is no authentication or encryption on this path.

## المدخلات · Inputs
- **المضيف / Host:** عنوان IP أو اسم النطاق لخادم Memcached · IP address or hostname of the Memcached server.
- **المنفذ / Port:** الافتراضي `11211` (منفذ Memcached القياسي) · Default `11211` (standard Memcached port).

## المخرجات · Outputs
**بالعربي:** كتلة نصية خام تحتوي رقم الإصدار ثم أزواج `STAT` مثل `STAT curr_connections`، `STAT get_hits`، `STAT get_misses`، `STAT bytes`، `STAT uptime`. يمكن نسخ النص كاملاً بزر النسخ. إذا ورد ردّ فارغ تظهر رسالة خطأ.
**English:** A raw text block containing the version number followed by `STAT` pairs such as `STAT curr_connections`, `STAT get_hits`, `STAT get_misses`, `STAT bytes`, `STAT uptime`. The full text can be copied. An empty reply surfaces an error message.

## مثال تشغيل · Worked example
**بالعربي:** الإدخال: `10.0.0.5` والمنفذ `11211`. المخرجات المتوقعة:
```
VERSION 1.6.21
STAT pid 1
STAT uptime 84213
STAT curr_connections 12
STAT get_hits 1048576
STAT get_misses 2048
STAT bytes 5242880
END
```
**English:** Input: `10.0.0.5` on port `11211`. Expected output:
```
VERSION 1.6.21
STAT pid 1
STAT uptime 84213
STAT curr_connections 12
STAT get_hits 1048576
STAT get_misses 2048
STAT bytes 5242880
END
```

## ملاحظات وقيود · Notes & limitations
**بالعربي:** البروتوكول النصي بلا مصادقة، لذا يعمل فقط مع خوادم يمكن الوصول إليها شبكياً وغالباً في شبكة داخلية موثوقة. لا يشمل ذلك خوادم SASL/الثنائية المؤمّنة. تُقرأ الاستجابة مرة واحدة فقط ولا تُحدَّث تلقائياً. الاتصال يُغلق فور اكتمال القراءة.
**English:** The text protocol is unauthenticated, so it works only against network-reachable servers, typically inside a trusted internal network. It does not cover SASL-secured or binary-protocol servers. The response is read once and not auto-refreshed; the connection closes as soon as the read completes.
