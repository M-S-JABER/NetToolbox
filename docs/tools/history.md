# History · السجل

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `history`

---

## نظرة عامة · Overview
**بالعربي:** يعرض السجل آخر العمليات التي شغّلتها عبر مختلف الأدوات (مثل الشبكة الفرعية، DNS، WHOIS، معلومات IP) في مكان واحد. كل شيء محلي على الجهاز، ويمكنك تصدير السجل أو استيراده أو مسحه.
**English:** History shows recent runs from across the tools (such as Subnet, DNS, WHOIS, IP Info) in one place. Everything is local on the device, and you can export, import, or clear the log.

## كيف تعمل · How it works
**بالعربي:** السجل مخزَّن محليًا في `HistoryStore` بلا أي اتصال بالشبكة. تسجّل الأدوات المدعومة كل تشغيل بمعرّف الأداة (`toolID`) والمُدخل (`input`) وملخّص (`summary`) وتاريخ. تعرض الشاشة القائمة مرتّبة، وتربط كل عنصر بأيقونة أداته عبر `ToolRegistry`. التصدير عبر `exportJSONString()` والاستيراد عبر `importJSON` من ملف `.json` أو نص. لا بروتوكول ولا منفذ ولا خدمة خارجية.
**English:** History is stored locally in `HistoryStore` with no network access. Supported tools log each run with its `toolID`, `input`, a `summary`, and a date. The screen lists them, linking each entry to its tool's icon via `ToolRegistry`. Export uses `exportJSONString()` and import uses `importJSON` from a `.json` or plain-text file. No protocol, port, or external service.

## المدخلات · Inputs
**بالعربي:** لا مدخلات مباشرة — يُملأ السجل تلقائيًا من الأدوات الأخرى. الإجراءات المتاحة: تصدير (مشاركة كنص JSON)، استيراد (اختيار ملف)، ومسح الكل. يمكن حذف عنصر مفرد بزر ✕.
**English:** No direct input — the log is populated automatically by other tools. Available actions: Export (share as JSON text), Import (pick a file), and Clear all. A single entry can be removed with its ✕ button.

## المخرجات · Outputs
**بالعربي:** قائمة "الأحدث" تعرض لكل عنصر: أيقونة الأداة واسمها، المُدخل، الملخّص، ووقت التشغيل (بصيغة `MMM d, HH:mm`). عند فراغ السجل تظهر حالة "لا يوجد سجل".
**English:** A "recent" list shows for each entry: the tool's icon and name, the input, the summary, and the run time (formatted `MMM d, HH:mm`). When empty, a "no history" empty state is shown.

## مثال تشغيل · Worked example
**بالعربي:** بعد استخدام أداة معلومات IP على `8.8.8.8` وحاسبة الشبكة الفرعية، يعرض السجل صفّين: "IP Info — 8.8.8.8 — 8.8.8.8 Mountain View, United States" و"Subnet — 192.168.1.0/24". اضغط "تصدير" لمشاركة الملف بصيغة JSON.
**English:** After using IP Info on `8.8.8.8` and the Subnet Calculator, History shows two rows: "IP Info — 8.8.8.8 — 8.8.8.8 Mountain View, United States" and "Subnet — 192.168.1.0/24". Tap Export to share the file as JSON.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** كل البيانات على الجهاز فقط ولا تُرفع لأي خادم. ليست كل الأدوات تسجّل في السجل — فقط تلك التي تستدعي `history.log`. الاستيراد يدمج/يستبدل حسب المنطق الداخلي للمخزن. لا يتطلب أي إذن أو إنترنت.
**English:** All data stays on-device and is never uploaded. Not every tool logs to History — only those that call `history.log`. Import merges/replaces per the store's internal logic. No permission or internet required.
