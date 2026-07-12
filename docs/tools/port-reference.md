# Common Ports Reference · مرجع المنافذ الشائعة

> **Category / التصنيف:** Calculators / الحاسبات  
> **Tool ID:** `port-reference`

---

## نظرة عامة · Overview
**بالعربي:** مرجع سريع للمنافذ الشائعة في بروتوكولي `TCP` و`UDP`. يعرض قائمة قابلة للبحث والتصفية تضم رقم المنفذ، البروتوكول، اسم الخدمة، ووصفاً موجزاً لها. مفيد أثناء إعداد جدران الحماية، تشخيص الاتصالات، ومراجعة قواعد الأمان.
**English:** A quick reference for common `TCP` and `UDP` ports. It shows a searchable, filterable list with the port number, protocol, service name, and a short description. Useful while configuring firewalls, diagnosing connections, and reviewing security rules.

## كيف تعمل · How it works
**بالعربي:** البيانات ثابتة داخل `PortDatabase.all` (نحو 79 مدخلاً لمنافذ معروفة) والتصفية في `PortReferenceViewModel` — **يعمل محلياً بالكامل بدون اتصال بالإنترنت**. البحث يطابق النص المُدخل مع بداية رقم المنفذ أو مع اسم الخدمة أو الوصف (غير حسّاس لحالة الأحرف). فلتر البروتوكول يقصر النتائج على `TCP` أو `UDP` أو الكل. لا يفتح أي منفذ ولا يفحص أي جهاز — إنه جدول مرجعي فقط.
**English:** The data is static inside `PortDatabase.all` (~79 well-known port entries) and filtering happens in `PortReferenceViewModel` — **runs 100% on-device, no network**. Search matches the query against the start of the port number, or against the service name or description (case-insensitive). The protocol filter limits results to `TCP`, `UDP`, or all. It does not open any port or scan any host — it is a reference table only.

## المدخلات · Inputs
| Field · الحقل | الوصف · Description |
|---|---|
| `query` | نص بحث: رقم منفذ (مثل `44`) أو اسم خدمة (`ssh`) أو كلمة في الوصف. Search text: port number, service name, or a word in the description. |
| `filter` | فلتر البروتوكول: `all` / `tcp` / `udp`. Protocol filter. |

## المخرجات · Outputs
**بالعربي:** قائمة صفوف، كل صف: رقم المنفذ، البروتوكول/البروتوكولات، اسم الخدمة، والوصف الموجز. أسماء الخدمات والأوصاف بالإنجليزية عمداً لأنها مصطلحات تقنية معيارية.
**English:** A list of rows, each with the port number, protocol(s), service name, and short description. Service names and descriptions are intentionally in English as they are standard technical vocabulary.

## مثال تشغيل · Worked example
**بالعربي:** بحث عن `443` →
- `443` · `TCP`/`UDP` · **HTTPS** · "Web traffic over TLS; UDP = HTTP/3 (QUIC)"

بحث عن `ssh` →
- `22` · `TCP` · **SSH** · "Secure Shell — remote login, SFTP, tunneling"

**English:** Search `443` →
- `443` · `TCP`/`UDP` · **HTTPS** · "Web traffic over TLS; UDP = HTTP/3 (QUIC)"

Search `ssh` →
- `22` · `TCP` · **SSH** · "Secure Shell — remote login, SFTP, tunneling"

## ملاحظات وقيود · Notes & limitations
**بالعربي:** القائمة منتقاة لأشهر المنافذ وليست شاملة لكامل سجل IANA. أداة مرجعية بحتة — لا فحص منافذ ولا اتصال بأي شبكة. تحديث القائمة يتطلب تحديث التطبيق.
**English:** The list is curated to the most common ports and is not the full IANA registry. It is purely a reference — no port scanning, no network access. Updating the list requires an app update.
