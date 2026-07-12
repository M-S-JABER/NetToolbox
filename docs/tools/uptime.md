# Uptime Monitor · مراقب التوفّر

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `uptime`

---

## نظرة عامة · Overview
**بالعربي:** مراقب التوفّر يفحص قائمة من الروابط دفعة واحدة ويبيّن أيها متاح (up) وأيها متعذّر (down) مع زمن الاستجابة لكل رابط. إنها مراقبة لحظية مصغّرة تعمل محليًا من جهازك دون خادم مراقبة خارجي.
**English:** The Uptime Monitor checks a list of URLs in one batch and shows which are up and which are down, along with each one's response time. It is a mini on-demand monitor that runs locally from your device with no external monitoring server.

## كيف تعمل · How it works
**بالعربي:** تُقسّم القائمة النصية على الأسطر أو الفواصل أو المسافات، وتُزال التكرارات مع الحفاظ على الترتيب. لكل رابط (يُضاف `https://` إن غاب البروتوكول) تُرسل طلب `GET` عبر `URLSession` بإعداد `ephemeral` مع مهلة 12 ثانية، وتُقاس المدة بساعة `ContinuousClock`. تُنفَّذ كل الفحوص بالتوازي عبر `withTaskGroup`. يُعدّ الرابط «متوفرًا» إذا كان رمز حالة HTTP ضمن النطاق 200–399؛ وأي خطأ اتصال أو انتهاء مهلة يجعله «متعذرًا».
**English:** The text list is split on newlines, commas, or spaces, and duplicates are removed while preserving order. For each URL (with `https://` prepended if the scheme is missing) a `GET` request is sent via an `ephemeral` `URLSession` with a 12-second timeout, and the duration is measured with `ContinuousClock`. All checks run concurrently via `withTaskGroup`. A URL is considered "up" if its HTTP status code is in the 200–399 range; any connection error or timeout marks it "down".

## المدخلات · Inputs
- **URL list / قائمة الروابط:** روابط متعددة مفصولة بأسطر أو فواصل أو مسافات (مثل `apple.com, github.com`). / Multiple URLs separated by newlines, commas, or spaces.

## المخرجات · Outputs
**بالعربي:** صف لكل رابط يحمل نقطة خضراء (متوفر) أو حمراء (متعذر)، ونص الرابط النهائي، وحالة مثل `200 · 245 ms`، أو `down` عند التعذّر.
**English:** One row per URL with a green dot (up) or red dot (down), the final URL text, and a status such as `200 · 245 ms`, or `down` on failure.

## مثال تشغيل · Worked example
**بالعربي:** المدخل `apple.com, github.com, no-such-host.invalid`. النتيجة: `https://apple.com` نقطة خضراء `200 · 210 ms`، `https://github.com` نقطة خضراء `200 · 180 ms`، `https://no-such-host.invalid` نقطة حمراء `down`.
**English:** Input `apple.com, github.com, no-such-host.invalid`. Result: `https://apple.com` green `200 · 210 ms`, `https://github.com` green `200 · 180 ms`, `https://no-such-host.invalid` red `down`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** الفحص لحظي وليس مراقبة مستمرة؛ لا توجد تنبيهات أو جدولة. يعتمد على رمز حالة HTTP فقط، فقد يظهر موقع يعيد صفحة خطأ 4xx كـ«متعذّر» رغم أن الخادم يعمل. لا يتطلب أذونات خاصة على iOS.
**English:** The check is a one-shot snapshot, not continuous monitoring; there are no alerts or scheduling. It relies only on the HTTP status code, so a site returning a 4xx error page may show as "down" even though the server is running. No special iOS permissions are required.
