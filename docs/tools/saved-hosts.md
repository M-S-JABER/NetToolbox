# Saved Hosts · المضيفون المحفوظون

> **Category / التصنيف:** Local Network / الشبكة المحلية  
> **Tool ID:** `saved-hosts`

---

## نظرة عامة · Overview
**بالعربي:** دفتر عناوين بسيط لحفظ المضيفين المتكرّرين (عناوين IP أو أسماء نطاقات أو عناوين MAC) باسم وملاحظة اختيارية، بحيث يمكن استدعاؤها بنقرة في الأدوات الأخرى بدل إعادة كتابتها. تُخزَّن البيانات محليًا على الجهاز وتُزامَن عبر iCloud عند توفّره.
**English:** A simple address book for storing frequently used hosts (IP addresses, domain names, or MAC addresses) with a name and an optional note, so they can be recalled with one tap in the other tools instead of retyping. Data is stored locally on the device and synced via iCloud when available.

## كيف تعمل · How it works
**بالعربي:** هذه الأداة لا تُجري أي اتصال شبكي؛ إنها مخزن بيانات محلي فقط. تُحفظ القائمة بصيغة JSON داخل `UserDefaults` تحت المفتاح `nettoolbox.hosts.v1` بواسطة `SavedHostsStore`. كل مضيف يحمل معرّفًا فريدًا (UUID) واسمًا وعنوانًا وملاحظة. عند إضافة مضيف يُقتطع الفراغ من العنوان، وإن تُرك الاسم فارغًا يُستخدم العنوان اسمًا. يستمع المخزن لإشعار `cloudSyncDidPull` فيعيد تحميل القائمة عندما تجلب مزامنة iCloud قيمًا أحدث. تظهر العناوين المحفوظة في أدوات أخرى (مثل Wake‑on‑LAN والكاميرا) عبر قائمة `SavedHostMenu`.
**English:** This tool performs no network activity; it is purely a local data store. The list is persisted as JSON in `UserDefaults` under the key `nettoolbox.hosts.v1` by `SavedHostsStore`. Each host carries a unique identifier (UUID), a name, an address, and a note. When a host is added, whitespace is trimmed from the address, and if the name is left blank the address is used as the name. The store listens for the `cloudSyncDidPull` notification and reloads when iCloud sync pulls in newer values. Saved hosts surface in other tools (such as Wake‑on‑LAN and Camera) through the `SavedHostMenu` picker.

## المدخلات · Inputs
**بالعربي:**
- **الاسم (Name):** تسمية اختيارية للمضيف؛ إن تُرك فارغًا يُستخدم العنوان.
- **العنوان (Address):** حقل إلزامي — عنوان IP مثل `192.168.1.50`، أو اسم نطاق، أو عنوان MAC. لوحة المفاتيح من نوع URL بدون تصحيح تلقائي. زر الحفظ معطّل ما لم يُملأ.
- **الملاحظات (Notes):** نص حر اختياري للسياق (مثل «راوتر غرفة المكتب»).
**English:**
- **Name:** an optional label for the host; if blank the address is used.
- **Address:** a required field — an IP like `192.168.1.50`, a domain name, or a MAC address. The keyboard is URL‑type with autocorrect off. The Save button is disabled until it is filled.
- **Notes:** optional free text for context (e.g. "office room router").

## المخرجات · Outputs
**بالعربي:** قائمة بالمضيفين المحفوظين، كل صف يعرض الاسم والملاحظة (إن وُجدت) والعنوان (قابل للنسخ بنقرة) وزر حذف. إن كانت القائمة فارغة تظهر رسالة توضيحية.
**English:** A list of saved hosts; each row shows the name, the note (if any), the address (copyable with a tap), and a delete button. If the list is empty an explanatory placeholder is shown.

## مثال تشغيل · Worked example
**بالعربي:** تكتب الاسم `NAS المنزل`، والعنوان `192.168.8.10`، والملاحظة `Synology - المكتب`، ثم تضغط «حفظ». يظهر الصف في القائمة. لاحقًا في أداة Wake‑on‑LAN أو الكاميرا يمكنك اختيار `192.168.8.10` من قائمة المضيفين مباشرة.
**English:** You type the name `Home NAS`, the address `192.168.8.10`, and the note `Synology - office`, then tap Save. The row appears in the list. Later, in the Wake‑on‑LAN or Camera tool, you can pick `192.168.8.10` straight from the saved‑hosts menu.

## ملاحظات وقيود · Notes & limitations
**بالعربي:**
- هذه الأداة لا تتصل بالشبكة، لذا لا تتطلب صلاحية «الشبكة المحلية». لكن الأدوات التي تستهلك هذه العناوين (مثل فحص المدى والكاميرا و Wake‑on‑LAN) تتطلب الصلاحية عند مخاطبة الشبكة المحلية. لتفعيلها: **الإعدادات ← NetToolbox ← الشبكة المحلية**، وبدونها تُرجع أدوات الاكتشاف نتائج فارغة.
- تُحفظ البيانات في `UserDefaults` على الجهاز؛ حذفها من هنا نهائي (مع الحذف من نسخة iCloud عند المزامنة).
**English:**
- This tool does no networking, so it does not require the Local Network permission. However, the tools that consume these addresses (range scanner, camera, Wake‑on‑LAN) require the permission when they touch the local network. Enable it via **Settings ← NetToolbox ← Local Network**; without it the discovery tools return empty results.
- Data is stored in `UserDefaults` on the device; deleting a host here is permanent (and removed from the iCloud copy on sync).
