# Guide · الدليل

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `guide`

---

## نظرة عامة · Overview
**بالعربي:** الدليل هو شاشة مساعدة مدمجة داخل التطبيق تشرح كيفية استخدام أدوات NetToolbox وإعداد الأذونات. محتواه ثابت ومُجمّع مع التطبيق نفسه ولا يتصل بأي خادم أو شبكة إطلاقًا. الهدف منه تعريفك بالصفحة الرئيسية والبحث والأدوات الأساسية وإذن الشبكة المحلية.
**English:** The Guide is an in-app help screen that explains how to use NetToolbox's tools and how to set up permissions. Its content is static and bundled with the app itself, with zero network access. It orients you to the home screen, search, the key tools, and the Local Network permission.

## كيف تعمل · How it works
**بالعربي:** الأداة عبارة عن قائمة ثابتة من الأقسام يعرضها التطبيق نصيًا فقط، دون أي بروتوكول أو منفذ أو خدمة خارجية. الأقسام المضمّنة هي: المقدمة (`intro`)، الصفحة الرئيسية (`home`)، الأدوات والبحث (`tools`)، معلومات الواي-فاي (`wifi`)، الأذونات (`permissions`)، الشبكة المحلية (`localnet`)، الأدوات الاحترافية (`pro`)، القيود (`limits`)، والاختبارات الذاتية (`tests`). كل قسم مجرد نص مُترجَم يُقرأ من ملفات التطبيق، فلا يوجد أي استعلام أو حساب.
**English:** The tool is a fixed list of sections rendered as text only — no protocol, port, or external service. The bundled sections are: intro, home, tools & search, Wi-Fi info, permissions, Local Network, professional tools, limits, and self-tests. Each section is simply localized text read from the app bundle; there is no query or computation.

## المدخلات · Inputs
**بالعربي:** لا توجد حقول إدخال. الأداة للقراءة فقط.
**English:** No input fields. The tool is read-only.

## المخرجات · Outputs
**بالعربي:** بطاقات نصية (SectionCard) لكل موضوع، مع أيقونة وعنوان ونص شرح. لا توجد قيم قابلة للنسخ أو نتائج مُحتسبة.
**English:** A stack of text cards (SectionCards), one per topic, each with an icon, title, and body text. There are no copyable values or computed results.

## مثال تشغيل · Worked example
**بالعربي:** افتح الدليل ← تظهر بطاقة "الشبكة المحلية" تشرح أن ماسح LAN وSSDP يحتاجان إذن الشبكة المحلية من iOS، وأنه يُفعَّل من *إعدادات iOS ← NetToolbox ← الشبكة المحلية* إذا لم يُعثَر على أجهزة.
**English:** Open the Guide → the "Local Network" card explains that the LAN Scanner and SSDP need the iOS Local Network permission, enabled via *iOS Settings → NetToolbox → Local Network* if nothing is found.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** لا يتصل بالإنترنت ولا يطلب أي إذن. المحتوى ثابت ولا يتحدّث ديناميكيًا؛ لتفاصيل كل أداة على حدة راجع صفحة الأداة نفسها. لا خصوصية مطروحة لأن لا بيانات تُرسَل.
**English:** No internet connection and no permission requested. Content is static and does not update dynamically; for per-tool detail see each tool's own page. No privacy concerns since nothing is transmitted.
