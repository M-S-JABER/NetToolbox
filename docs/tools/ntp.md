# NTP Time Query · استعلام وقت NTP

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `ntp`

---

## نظرة عامة · Overview
**بالعربي:** أداة استعلام وقت NTP تسأل خادم وقت شبكي عن الوقت الحالي وتقارنه بساعة جهازك لحساب الفارق (offset). تستخدم بروتوكول SNTP (RFC 4330) فوق UDP، وتنفّذ بناء الطلب وتحليل الرد محليًا.
**English:** The NTP Time Query tool asks a network time server for the current time and compares it to your device's clock to compute the offset. It uses the SNTP protocol (RFC 4330) over UDP, building the request and parsing the reply locally.

## كيف تعمل · How it works
**بالعربي:** تبني الأداة رسالة طلب SNTP طولها 48 بايت: البايت الأول `0x1B` (يعني LI=0، VN=3، Mode=3 أي عميل) والباقي أصفار. تُرسل عبر `UDPExchange` إلى الخادم على المنفذ `123` (UDP) بمهلة 5 ثوانٍ. من الرد تُقرأ **طابع الإرسال الزمني** (transmit timestamp) من البايتات 40–43 كعدد صحيح 32-بت لثوانٍ منذ حقبة NTP (1900-01-01)، ثم يُطرح منها الإزاحة الثابتة `2208988800` للتحويل إلى حقبة يونكس والحصول على `Date`. يُحسب الفارق كـ `serverTime.timeIntervalSinceNow`.
**English:** The tool builds a 48-byte SNTP request message: the first byte is `0x1B` (meaning LI=0, VN=3, Mode=3, i.e. client) with the rest zeroed. It is sent via `UDPExchange` to the server on port `123` (UDP) with a 5-second timeout. From the reply it reads the **transmit timestamp** from bytes 40–43 as a 32-bit integer of seconds since the NTP epoch (1900-01-01), then subtracts the fixed offset `2208988800` to convert to the Unix epoch and obtain a `Date`. The offset is computed as `serverTime.timeIntervalSinceNow`.

## المدخلات · Inputs
- **Server / الخادم:** اسم خادم NTP (افتراضيًا `time.apple.com`). / NTP server hostname (defaults to `time.apple.com`).

## المخرجات · Outputs
**بالعربي:** **وقت الخادم** بصيغة `yyyy-MM-dd HH:mm:ss UTC`، و**الفارق** (offset) بالثواني بدقة ثلاث خانات وإشارة، مثل `+0.032 s` (ساعة جهازك متأخرة) أو `-0.045 s` (متقدّمة).
**English:** The **server time** formatted as `yyyy-MM-dd HH:mm:ss UTC`, and the **offset** in seconds with three decimals and a sign, such as `+0.032 s` (your clock is behind) or `-0.045 s` (ahead).

## مثال تشغيل · Worked example
**بالعربي:** المدخل `time.apple.com`. النتيجة: وقت الخادم `2026-07-12 09:15:03 UTC`، والفارق `+0.021 s`، أي أن ساعة جهازك متأخرة بنحو 21 مللي ثانية.
**English:** Input `time.apple.com`. Result: server time `2026-07-12 09:15:03 UTC`, offset `+0.021 s`, meaning your device clock is about 21 milliseconds behind.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** يقرأ SNTP طابع الإرسال فقط ولا يعوّض عن زمن الرحلة على الشبكة، لذا يشمل الفارق تأخير الشبكة وقد لا يعكس الانحراف الحقيقي بدقة المللي ثانية. بعض الشبكات تحجب المنفذ `123` (UDP). لا يتطلب أذونات خاصة على iOS.
**English:** SNTP here reads only the transmit timestamp and does not compensate for network round-trip time, so the offset includes network delay and may not reflect true skew at millisecond precision. Some networks block port `123` (UDP). No special iOS permissions are required.
