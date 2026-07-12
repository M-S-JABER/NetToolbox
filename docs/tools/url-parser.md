# URL Parser · مُحلِّل الروابط

> **Category / التصنيف:** Calculators / الحاسبات  
> **Tool ID:** `url-parser`

---

## نظرة عامة · Overview
**بالعربي:** أداة تُفكّك رابط URL إلى مكوّناته: البروتوكول والمستخدم وكلمة المرور والمضيف والمنفذ والمسار والجزء (fragment) ومعاملات الاستعلام (query). تعمل محلياً بالكامل بدون إنترنت — لا تفتح الرابط ولا تتصل به.  
**English:** Breaks a URL into its components: scheme, user, password, host, port, path, fragment, and query parameters. Runs 100% on-device with no network — it never opens or contacts the URL.

## كيف تعمل · How it works
**بالعربي:** يُقتطع النص ويُمرَّر إلى `URLComponents` من Foundation. يُعتبر الرابط صالحاً فقط إذا كان له `scheme` أو `host` على الأقل. ثم تُبنى صفوف من المكوّنات غير الفارغة بالترتيب: `Scheme`, `User`, `Password`, `Host`, `Port`, `Path`, `Fragment`. بعدها يُضاف لكل عنصر استعلام صفٌّ بعنوان `query: <name>` وقيمته. المكوّنات الفارغة تُحذَف من العرض. التحليل محلي بالكامل عبر `URLComponents` دون أي طلب شبكي.  
**English:** The text is trimmed and passed to Foundation's `URLComponents`. The URL is considered valid only if it has at least a `scheme` or a `host`. Rows are then built from the non-empty components in order: `Scheme`, `User`, `Password`, `Host`, `Port`, `Path`, `Fragment`. Then each query item adds a row labeled `query: <name>` with its value. Empty components are omitted from the display. Parsing is fully local via `URLComponents` with no network request.

## المدخلات · Inputs
**بالعربي:**
- `URL` — الرابط المراد تحليله (يقبل حتى 4 أسطر)، بلوحة مفاتيح روابط وبدون تصحيح تلقائي.

**English:**
- `URL` — the URL to parse (up to 4 lines), with a URL keyboard and autocorrection disabled.

## المخرجات · Outputs
**بالعربي:** جدول من التسميات والقيم، كل قيمة قابلة للنسخ. تُعرَض المكوّنات الموجودة فقط، ويظهر كل معامل استعلام في صفّ مستقل. رابط بلا scheme ولا host يُظهر رسالة "غير صالح".  
**English:** A table of labels and values, each value copyable. Only present components are shown, and each query parameter appears in its own row. A URL with neither scheme nor host shows an "invalid" message.

## مثال تشغيل · Worked example
**بالعربي:** إدخال `https://user:pass@example.com:8443/api/v1?q=cats&page=2#top` يُنتج: `Scheme=https`، `User=user`، `Password=pass`، `Host=example.com`، `Port=8443`، `Path=/api/v1`، `Fragment=top`، `query: q=cats`، `query: page=2`.  
**English:** Input `https://user:pass@example.com:8443/api/v1?q=cats&page=2#top` yields: `Scheme=https`, `User=user`, `Password=pass`, `Host=example.com`, `Port=8443`, `Path=/api/v1`, `Fragment=top`, `query: q=cats`, `query: page=2`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** يعتمد على قواعد `URLComponents`؛ الروابط المشوّهة أو ذات الأحرف غير المُرمَّزة قد تفشل في التحليل. يُظهر كلمة المرور إن وُجدت في الرابط (تحذير خصوصية عند اللصق). لا فكّ ترميز نسبة مئوية إضافي للقيم يتجاوز ما يُخرجه `URLComponents`. لا اتصال بالشبكة إطلاقاً.  
**English:** It follows `URLComponents` rules; malformed URLs or ones with unencoded characters may fail to parse. It reveals the password if present in the URL (a privacy note when pasting). No extra percent-decoding of values beyond what `URLComponents` provides. No network access at all.
