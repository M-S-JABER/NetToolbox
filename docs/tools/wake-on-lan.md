# Wake‑on‑LAN · التنبيه عبر الشبكة

> **Category / التصنيف:** Local Network / الشبكة المحلية  
> **Tool ID:** `wake-on-lan`

---

## نظرة عامة · Overview
**بالعربي:** توقظ هذه الأداة جهازًا نائمًا أو مُطفأ (يدعم Wake‑on‑LAN) عن بُعد بإرسال «حزمة سحرية» (magic packet) إلى عنوان MAC الخاص به عبر الشبكة المحلية. مفيدة لتشغيل حاسوب مكتبي أو خادم NAS دون الوصول الفيزيائي إليه.
**English:** This tool wakes a sleeping or powered‑off device (that supports Wake‑on‑LAN) remotely by sending a "magic packet" to its MAC address over the local network. Useful for powering on a desktop PC or NAS without physically reaching it.

## كيف تعمل · How it works
**بالعربي:** تبني الأداة «الحزمة السحرية» القياسية: 6 بايتات من `0xFF` يتبعها عنوان MAC الهدف مكرّرًا 16 مرة (مجموعها 102 بايت). ثم ترسلها عبر مقبس UDP مُفعَّل عليه خيار البث (`SO_BROADCAST`) إلى عنوان البث المُدخل (افتراضيًّا `255.255.255.255`) على المنفذ المُدخل (افتراضيًّا `9`، وأحيانًا `7`). يُحلَّل عنوان البث بـ `inet_pton` (الذي يتعامل مع `255.255.255.255` بشكل صحيح). عند استقبال بطاقة الشبكة للحزمة الموجّهة إلى عنوان MAC الخاص بها يوقظ نظامها الجهاز. الأداة ترسل الحزمة فقط ولا تنتظر ردًّا — لا توجد طريقة قياسية لتأكيد الاستيقاظ عبر WoL.
**English:** The tool builds the standard "magic packet": 6 bytes of `0xFF` followed by the target MAC address repeated 16 times (102 bytes total). It then sends it over a broadcast‑enabled UDP socket (`SO_BROADCAST`) to the entered broadcast address (default `255.255.255.255`) on the entered port (default `9`, sometimes `7`). The broadcast address is parsed with `inet_pton` (which handles `255.255.255.255` correctly). When the target's network card receives the packet addressed to its MAC, its firmware wakes the machine. The tool only sends the packet and does not wait for a reply — there is no standard way to confirm the wake over WoL.

## المدخلات · Inputs
**بالعربي:**
- **عنوان MAC (MAC):** إلزامي — عنوان الجهاز الهدف مثل `A4:BB:6D:1F:2E:9C` (تُقبل فواصل `:` أو `-`). يمكن اختياره من قائمة المضيفين المحفوظين. زر الإرسال يبقى نشطًا لكنه لا يفعل شيئًا إن كان الحقل فارغًا.
- **عنوان البث (Broadcast):** افتراضيًّا `255.255.255.255`؛ يمكن تخصيصه لبث الشبكة الفرعية مثل `192.168.8.255` لتوجيه أدقّ.
- **المنفذ (Port):** افتراضيًّا `9`؛ يُقبل أيضًا `7`. إن كانت القيمة غير رقمية تُستخدم `9`.
**English:**
- **MAC:** required — the target device's address such as `A4:BB:6D:1F:2E:9C` (`:` or `-` separators accepted). It can be picked from the saved‑hosts menu. The Send button stays enabled but does nothing if the field is empty.
- **Broadcast:** default `255.255.255.255`; can be set to a subnet broadcast such as `192.168.8.255` for more targeted delivery.
- **Port:** default `9`; `7` is also accepted. A non‑numeric value falls back to `9`.

## المخرجات · Outputs
**بالعربي:** عند نجاح الإرسال تظهر بطاقة حالة بشارة «تم الإرسال» ونص تأكيد. عند الفشل (عنوان MAC غير صالح، تعذّر إنشاء المقبس، أو فشل الإرسال) تظهر بطاقة خطأ بوصف السبب. لاحظ أن «تم الإرسال» يعني أن الحزمة غادرت الجهاز، لا أن الجهاز الهدف استيقظ فعلًا.
**English:** On a successful send a status card appears with a "sent" badge and a confirmation message. On failure (invalid MAC, socket could not be created, or send failed) an error card describes the cause. Note that "sent" means the packet left the device, not that the target actually woke.

## مثال تشغيل · Worked example
**بالعربي:** تريد إيقاظ خادم NAS. تُدخل عنوان MAC `00:11:32:AA:BB:CC`، وتترك البث `255.255.255.255` والمنفذ `9`، ثم تضغط «إيقاظ». تظهر شارة «تم الإرسال». يستيقظ الخادم خلال ثوانٍ إن كان WoL مُفعَّلًا في إعداداته وفي بطاقة الشبكة.
**English:** You want to wake a NAS. You enter MAC `00:11:32:AA:BB:CC`, leave broadcast `255.255.255.255` and port `9`, then tap "Wake." The "sent" badge appears. The server wakes within seconds if WoL is enabled in its settings and network card.

## ملاحظات وقيود · Notes & limitations
**بالعربي:**
- يستدعي إرسال حزمة البث على الشبكة المحلية صلاحية **«الشبكة المحلية»** في iOS. لتفعيلها: **الإعدادات ← NetToolbox ← الشبكة المحلية**. بدونها قد يفشل الإرسال ولا يصل أي شيء إلى الجهاز الهدف.
- يجب أن يكون Wake‑on‑LAN مُفعَّلًا في BIOS/UEFI أو إعدادات نظام الجهاز الهدف وفي بطاقة شبكته، وأن يبقى الجهاز متصلًا بالطاقة والشبكة السلكية عادةً.
- تعمل الحزمة السحرية داخل الشبكة المحلية فقط؛ الإيقاظ عبر الإنترنت يتطلب إعدادًا إضافيًّا في الراوتر (توجيه/بث موجّه) خارج نطاق هذه الأداة.
- الأداة لا تؤكّد الاستيقاظ؛ للتحقق استخدم «فاحص مدى IP» أو حاول الاتصال بالجهاز بعد لحظات.
**English:**
- Sending the broadcast packet on the local network invokes the iOS **Local Network** permission. Enable it via **Settings ← NetToolbox ← Local Network**. Without it the send may fail and nothing reaches the target.
- Wake‑on‑LAN must be enabled in the target's BIOS/UEFI or OS settings and its network card, and the device must usually stay connected to power and wired network.
- The magic packet works within the local network only; waking over the internet requires extra router configuration (directed broadcast/forwarding) beyond this tool.
- The tool does not confirm the wake; to verify, use the "IP Range Scanner" or try connecting to the device after a moment.
