# MikroTik RouterOS API · واجهة MikroTik RouterOS API

> **Category / التصنيف:** Professional / احترافي  
> **Tool ID:** `mikrotik-api`

---

## نظرة عامة · Overview
**بالعربي:** طرفية حيّة تتصل بموجّهات MikroTik عبر واجهة RouterOS API على منفذ TCP رقم `8728`. تسمح بتسجيل الدخول ثم تنفيذ أوامر RouterOS (مثل `/system/resource/print`) وعرض الردود كسجلات منظَّمة بحقول `مفتاح: قيمة`.
**English:** A live terminal that connects to MikroTik routers over the RouterOS API on TCP port `8728`. It lets you log in and then run RouterOS commands (such as `/system/resource/print`), showing replies as structured records of `key: value` fields.

## كيف تعمل · How it works
**بالعربي:** تفتح الأداة اتصال TCP إلى `host:port` (بمهلة 8 ثوانٍ) ثم تسجّل الدخول بـ **تسجيل الدخول العادي** (plain login) المدعوم في RouterOS 6.43 فأحدث، بإرسال الجملة `/login =name=<المستخدم> =password=<كلمة المرور>`. بروتوكول API يعتمد على "جُمَل" (sentences) مكوّنة من "كلمات" (words) مؤطّرة بطول مسبوق؛ يتولّى `MikroTikProtocol` ترميز/فك الجُمَل. تُرسَل الأوامر بتقسيم النص على المسافات إلى كلمات، وتُقرأ الردود حتى تصل جملة `!done` أو `!fatal`. تُنسَّق الردود: كل `!re` سجل مرقَّم بحقوله، و`!trap`/`!fatal` تظهر كأخطاء.
**English:** The tool opens a TCP connection to `host:port` (8-second timeout) then logs in with **plain login** (supported on RouterOS 6.43+) by sending the sentence `/login =name=<user> =password=<password>`. The API protocol is built on "sentences" made of length-prefixed "words"; `MikroTikProtocol` handles encoding/decoding. Commands are split on spaces into words, and replies are read until a `!done` or `!fatal` sentence arrives. Replies are formatted: each `!re` is a numbered record with its fields, and `!trap`/`!fatal` appear as errors.

## المدخلات · Inputs
- **المضيف / Host:** عنوان الموجّه · Router address.
- **المنفذ / Port:** الافتراضي `8728` (منفذ RouterOS API غير المشفّر) · Default `8728` (unencrypted RouterOS API port).
- **المستخدم / User:** اسم المستخدم، الافتراضي `admin` · Username, default `admin`.
- **كلمة المرور / Password:** كلمة مرور الحساب · Account password.
- **الأمر / Command:** أمر RouterOS بصيغة API مثل `/interface/print` · A RouterOS command in API form, e.g. `/interface/print`.

**بالعربي:** يوفّر شريط أوامر سريعة جاهزة: `/system/resource/print`، `/system/identity/print`، `/interface/print`، `/ip/address/print`، `/ip/route/print`، `/ip/dhcp-server/lease/print`، `/system/clock/print`، `/log/print`.
**English:** A quick-commands bar provides ready presets: `/system/resource/print`, `/system/identity/print`, `/interface/print`, `/ip/address/print`, `/ip/route/print`, `/ip/dhcp-server/lease/print`, `/system/clock/print`, `/log/print`.

## المخرجات · Outputs
**بالعربي:** طرفية نصية تعرض: سطر الأمر المُدخَل، ثم لكل سجل `!re` عنواناً مثل `RECORD 1` وحقوله بمحاذاة `مفتاح: قيمة`، ثم سطر `done · N records`. تظهر الأخطاء بعلامة تحذير. يمكن مشاركة النص كاملاً أو مسحه.
**English:** A text terminal showing: the entered command line, then for each `!re` record a header like `RECORD 1` with aligned `key: value` fields, then a `done · N records` line. Errors appear with a warning marker. The full transcript can be shared or cleared.

## مثال تشغيل · Worked example
**بالعربي:** اتصل بـ `192.168.88.1:8728` بالمستخدم `admin`، ثم شغّل `/system/resource/print`. النتيجة سجل واحد بحقول مثل:
```
❯ /system/resource/print
── RECORD 1 ──
  uptime: 3w4d10h
  version: 7.15.2 (stable)
  board-name: hAP ac²
  cpu-load: 3
  free-memory: 201351168
done · 1 records
```
**English:** Connect to `192.168.88.1:8728` as `admin`, then run `/system/resource/print`. The result is one record with fields such as:
```
❯ /system/resource/print
── RECORD 1 ──
  uptime: 3w4d10h
  version: 7.15.2 (stable)
  board-name: hAP ac²
  cpu-load: 3
  free-memory: 201351168
done · 1 records
```

## ملاحظات وقيود · Notes & limitations
**بالعربي:** يستخدم المنفذ `8728` غير المشفّر، لذا تُرسَل بيانات الاعتماد والأوامر بنص واضح عبر الشبكة — استخدمه في شبكة موثوقة فقط، وليس عبر الإنترنت المكشوف (منفذ API-SSL المشفّر `8729` غير مدعوم هنا). يتطلب RouterOS 6.43 أو أحدث لتسجيل الدخول العادي. مهلة كل عملية 8 ثوانٍ. كلمة المرور تُدخل في حقل آمن.
**English:** It uses the unencrypted port `8728`, so credentials and commands are sent in clear text over the network — use it only on a trusted network, not over the open internet (the encrypted API-SSL port `8729` is not supported here). Plain login requires RouterOS 6.43 or newer. Each operation times out after 8 seconds. The password is entered in a secure field.
