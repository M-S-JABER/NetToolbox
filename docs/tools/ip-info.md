# IP Info Lookup · بحث معلومات العنوان

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `ip-info`

---

## نظرة عامة · Overview
**بالعربي:** أداة للبحث عن تفاصيل الموقع الجغرافي ومزوّد الخدمة لأي عنوان IP أو اسم مضيف تُدخله أنت — وليس فقط عنوانك الخاص. تعرض النتيجة على شكل بطاقة معلومات مع خريطة تحدّد الموقع التقريبي.
**English:** A tool to look up geo and ISP details for any IP address or hostname you enter — not just your own. The result is shown as an info card plus a map pinning the approximate location.

## كيف تعمل · How it works
**بالعربي:** ترسل الأداة طلب HTTPS إلى `https://ipwho.is/<الاستعلام>` حيث `<الاستعلام>` هو العنوان أو المضيف بعد ترميزه (URL-encoding). خدمة ipwho.is تُرجع JSON فيه حقل `success`؛ إن كان `false` تُعتبر النتيجة خطأ. عند النجاح تُستخرج الدولة والمدينة والإحداثيات ومزوّد الخدمة والمؤسسة وASN والمنطقة الزمنية. البروتوكول HTTPS على المنفذ `443`؛ لا ICMP ولا DNS خام — الخادم نفسه يحلّ اسم المضيف.
**English:** The tool sends an HTTPS request to `https://ipwho.is/<query>` where `<query>` is the URL-encoded address or hostname. The ipwho.is service returns JSON with a `success` field; if it is `false`, the result is treated as an error. On success it extracts country, city, coordinates, ISP, organization, ASN, and timezone. Protocol is HTTPS on port `443`; no ICMP or raw DNS — the server itself resolves any hostname.

## المدخلات · Inputs
**بالعربي:** حقل نصي واحد: عنوان IPv4/IPv6 أو اسم مضيف (مثل `8.8.8.8` أو `example.com`). يمكن اختيار مضيف محفوظ من قائمة "المضيفين المحفوظين".
**English:** A single text field: an IPv4/IPv6 address or a hostname (e.g. `8.8.8.8` or `example.com`). You can also pick a saved host from the Saved Hosts menu.

## المخرجات · Outputs
**بالعربي:** عنوان IP قابل للنسخ، الدولة (مع الرمز)، المدينة، ISP، المؤسسة، `ASNxxxxx`، المنطقة الزمنية، الإحداثيات (خط عرض/طول بأربع منازل)، وخريطة تفاعلية بعلامة على الموقع. يوجد زر مشاركة للنتيجة، وتُسجَّل العملية في سجل التاريخ (History).
**English:** A copyable IP, country (with code), city, ISP, organization, `ASNxxxxx`, timezone, coordinates (lat/long to four decimals), and an interactive map with a marker. A Share button exports the result, and the lookup is logged to History.

## مثال تشغيل · Worked example
**بالعربي:** إدخال `8.8.8.8` ← الدولة "United States (US)"، ISP "Google LLC"، `AS15169`، الإحداثيات `37.4056, -122.0775` تقريبًا، مع خريطة تُظهر الموقع.
**English:** Enter `8.8.8.8` → country "United States (US)", ISP "Google LLC", `AS15169`, coordinates approximately `37.4056, -122.0775`, with a map showing the location.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** الدقة الجغرافية تقريبية من قاعدة بيانات ipwho.is. يُرسَل العنوان الذي تكتبه إلى ipwho.is فقط. يتطلب اتصال إنترنت. الخريطة معطّلة اللمس (عرض فقط).
**English:** Geo accuracy is approximate, from the ipwho.is database. The address you type is sent to ipwho.is only. Internet is required. The map is non-interactive (display only).
