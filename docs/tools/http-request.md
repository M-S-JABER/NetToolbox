# HTTP Request · طلب HTTP

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `http-request`

---

## نظرة عامة · Overview
**بالعربي:** عميل HTTP مصغّر يتيح لك إرسال طلب مخصّص باختيار الطريقة (method) والرابط والترويسات (headers) والجسم (body)، ثم عرض رمز الحالة والترويسات والجسم في الرد. مفيد لاختبار واجهات REST سريعًا من الجهاز.
**English:** A mini HTTP client that lets you send a custom request with your chosen method, URL, headers, and body, then view the response status code, headers, and body. Handy for quickly testing REST APIs from the device.

## كيف تعمل · How it works
**بالعربي:** تبني الأداة `URLRequest` عبر `URLSession` (جلسة مؤقتة `ephemeral`) على البروتوكول والمنفذ المشتقّين من الرابط (عادةً HTTPS منفذ `443` أو HTTP منفذ `80`). إذا لم يبدأ الرابط بـ `http` يُضاف `https://` تلقائيًا. تُضبط مهلة 20 ثانية وترويسة `User-Agent: NetToolbox/1.0`، وتُحلَّل الترويسات المُدخلة سطرًا بسطر (`Key: Value`). يُرسَل الجسم فقط مع الطرق غير GET/HEAD. يُقتطَع الجسم المعروض إلى أول 20000 حرف. لا خدمة خارجية — يذهب الطلب مباشرةً إلى الخادم الذي تحدّده.
**English:** The tool builds a `URLRequest` sent via `URLSession` (an ephemeral session) over whatever protocol and port the URL implies (typically HTTPS on port `443` or HTTP on port `80`). If the URL doesn't start with `http`, `https://` is prepended automatically. A 20-second timeout and a `User-Agent: NetToolbox/1.0` header are set, and your headers are parsed line by line (`Key: Value`). A body is sent only for methods other than GET/HEAD. The displayed body is truncated to the first 20,000 characters. No external service — the request goes straight to the server you name.

## المدخلات · Inputs
**بالعربي:**
- **الطريقة:** واحدة من `GET`، `POST`، `PUT`، `PATCH`، `DELETE`، `HEAD` (اختيار شريطي).
- **الرابط:** عنوان الطلب (يمكن اختيار مضيف محفوظ).
- **الترويسات:** سطر لكل ترويسة بصيغة `Key: Value`.
- **الجسم:** نص الطلب (يظهر فقط للطرق غير GET/HEAD).
**English:**
- **Method:** one of `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD` (segmented picker).
- **URL:** the request address (a saved host can be picked).
- **Headers:** one `Key: Value` per line.
- **Body:** the request payload (shown only for non-GET/HEAD methods).

## المخرجات · Outputs
**بالعربي:** بطاقة الحالة تعرض رمز الاستجابة مع شارة ملوّنة (أخضر 2xx، أزرق 3xx، أصفر 4xx، أحمر غير ذلك). بطاقة الجسم تعرض نص الرد قابلًا للتحديد والنسخ. (تُجمَّع الترويسات وتُرتَّب داخليًا في النتيجة.)
**English:** A status card shows the response code with a colored badge (green 2xx, blue 3xx, amber 4xx, red otherwise). A body card shows selectable, copyable response text. (Response headers are collected and sorted in the result internally.)

## مثال تشغيل · Worked example
**بالعربي:** الطريقة `GET`، الرابط `https://api.github.com` ← الحالة `200`، والجسم JSON يبدأ بروابط الواجهة. إرسال `POST` إلى `https://httpbin.org/post` بجسم `{"a":1}` وترويسة `Content-Type: application/json` ← `200` مع صدى للبيانات المُرسَلة.
**English:** Method `GET`, URL `https://api.github.com` → status `200` and a JSON body starting with the API endpoint links. `POST` to `https://httpbin.org/post` with body `{"a":1}` and header `Content-Type: application/json` → `200` echoing the sent data.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** الجسم المعروض محدود بـ 20000 حرف والمهلة 20 ثانية. عند انقطاع الإنترنت تظهر رسالة "غير متصل". لا يُخزَّن الطلب أو الرد. أرسل الطلبات فقط إلى خوادم مصرّح لك باختبارها. البيانات تذهب مباشرةً للخادم الهدف دون وسيط.
**English:** The displayed body is capped at 20,000 characters and the timeout is 20 seconds. If the internet is down, an "offline" message appears. Neither request nor response is stored. Only send requests to servers you're authorized to test. Data goes directly to the target server with no intermediary.
