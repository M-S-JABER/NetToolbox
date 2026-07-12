# HTTP Headers · ترويسات HTTP

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `http-headers`

---

## نظرة عامة · Overview
**بالعربي:** أداة ترويسات HTTP تجلب عنوانًا وتعرض سطر الحالة وكل ترويسات الاستجابة مرتبةً أبجديًا. مفيدة لفحص ترويسات الأمان، التخزين المؤقت، نوع المحتوى، والخادم. تعمل محليًا عبر مكدّس الشبكة في النظام.
**English:** The HTTP Headers tool fetches a URL and displays the status line and all response headers, sorted alphabetically. Useful for inspecting security headers, caching, content type, and the server. It runs locally via the system network stack.

## كيف تعمل · How it works
**بالعربي:** إذا لم يبدأ العنوان بـ `http://` أو `https://` تضيف الأداة `https://`. تُرسل طلب `GET` عبر `URLSession` بإعداد `ephemeral` مع مهلة 15 ثانية وترويسة `User-Agent: NetToolbox/1.0`. من `HTTPURLResponse` تقرأ رمز الحالة، العنوان النهائي بعد إعادة التوجيه (`http.url`)، وكل الترويسات (`allHeaderFields`) بعد تحويلها إلى أزواج اسم/قيمة وترتيبها أبجديًا حسب الاسم. إذا تعذّر الاتصال بالإنترنت تُرجع الأداة خطأ «offline».
**English:** If the URL does not begin with `http://` or `https://`, the tool prepends `https://`. It issues a `GET` request through an `ephemeral` `URLSession` with a 15-second timeout and a `User-Agent: NetToolbox/1.0` header. From the `HTTPURLResponse` it reads the status code, the final URL after redirects (`http.url`), and all headers (`allHeaderFields`), converted to name/value pairs and sorted alphabetically by name. If the internet is unreachable it returns an `offline` error.

## المدخلات · Inputs
- **URL / العنوان:** عنوان الصفحة أو نقطة النهاية (مثل `apple.com`). إن غاب البروتوكول يُفترض `https`. / Page or endpoint URL; `https` is assumed if the scheme is missing.

## المخرجات · Outputs
**بالعربي:** بطاقة **الحالة**: رمز HTTP بلون حسب الفئة (2xx نجاح، 3xx معلومة، 4xx تحذير، 5xx خطأ) والعنوان النهائي القابل للنسخ. وبطاقة **الترويسات**: كل ترويسة باسمها وقيمتها (قابلة للتحديد والنسخ).
**English:** A **Status** card: the HTTP code colored by class (2xx success, 3xx info, 4xx warning, 5xx error) and the copyable final URL. A **Headers** card: every header with its name and value (selectable and copyable).

## مثال تشغيل · Worked example
**بالعربي:** المدخل `github.com`. النتيجة: الحالة `200`، العنوان النهائي `https://github.com/`، والترويسات مثل `content-type: text/html; charset=utf-8`، `server: GitHub.com`، `strict-transport-security: max-age=31536000`.
**English:** Input `github.com`. Result: status `200`, final URL `https://github.com/`, and headers such as `content-type: text/html; charset=utf-8`, `server: GitHub.com`, `strict-transport-security: max-age=31536000`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** تتبع الأداة إعادة التوجيه تلقائيًا فتعرض ترويسات الاستجابة النهائية فقط. بعض الخوادم تختلف استجابتها لطلب `GET` عن `HEAD`. الجلسة `ephemeral` بلا كوكيز أو تخزين مؤقت. لا يتطلب أذونات خاصة على iOS.
**English:** The tool follows redirects automatically, so it shows only the final response's headers. Some servers respond differently to `GET` versus `HEAD`. The `ephemeral` session carries no cookies or cache. No special iOS permissions are required.
