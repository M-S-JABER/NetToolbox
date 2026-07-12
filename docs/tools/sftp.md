# SFTP Browser · متصفّح SFTP

> **Category / التصنيف:** Professional / احترافي  
> **Tool ID:** `sftp`

---

## نظرة عامة · Overview
**بالعربي:** أداة لتصفّح الملفات على خادم بعيد وتنزيلها بأمان عبر بروتوكول SFTP (نقل الملفات فوق SSH). تعتمد على نفس عميل SSH-2 المبني من الصفر داخل التطبيق، فكل ما يمرّ يكون مشفّرًا. تتيح استعراض المجلّدات، والدخول إليها، وتنزيل الملفات ومشاركتها.

**English:** A tool for browsing and securely downloading files on a remote server over SFTP (file transfer over SSH). It uses the same from-scratch SSH-2 client built into the app, so everything is encrypted. You can list directories, navigate into them, and download and share files.

## كيف تعمل · How it works
**بالعربي:** الأداة تتصل بالمنفذ `22` افتراضيًا (نفس منفذ SSH، لأن SFTP نظام فرعي داخل SSH). بعد إتمام مصافحة SSH-2 والمصادقة (تبادل مفاتيح `curve25519-sha256` وتشفير `aes256-gcm@openssh.com`)، تُفتح قناة `session` ويُطلَب النظام الفرعي `subsystem` باسم `sftp`، ثم تجري مصافحة SFTP بالإصدار 3. يُرسَل `SSH_FXP_INIT`، وللاستعراض تُستخدم `SSH_FXP_OPENDIR` ثم `SSH_FXP_READDIR` المتكرّرة حتى نهاية القائمة، وللتنزيل `SSH_FXP_OPEN` ثم `SSH_FXP_READ` بمقاطع بحجم `32768` بايت. كل حزمة SFTP تُغلَّف داخل بيانات القناة (`CHANNEL_DATA`). التنفيذ أصلي بالكامل بدون مكتبات خارجية.

**English:** The tool connects to port `22` by default (the same port as SSH, since SFTP is a subsystem inside SSH). After completing the SSH-2 handshake and authentication (`curve25519-sha256` key exchange, `aes256-gcm@openssh.com` encryption), it opens a `session` channel and requests the `subsystem` named `sftp`, then performs an SFTP version-3 handshake. It sends `SSH_FXP_INIT`; for listing it uses `SSH_FXP_OPENDIR` then repeated `SSH_FXP_READDIR` until end-of-list, and for downloading `SSH_FXP_OPEN` then `SSH_FXP_READ` in `32768`-byte chunks. Every SFTP packet is wrapped inside channel data (`CHANNEL_DATA`). The implementation is fully native with no external libraries.

## المدخلات · Inputs
- **Host / المضيف:** اسم النطاق أو IP للخادم · Hostname or IP of the server.
- **Port / المنفذ:** افتراضيًا `22` · Defaults to `22`.
- **Username / اسم المستخدم:** الافتراضي `admin` · Defaults to `admin`.
- **Auth mode / نمط المصادقة:** كلمة مرور أو مفتاح `ed25519` خاص بصيغة OpenSSH PEM · Password or a private `ed25519` OpenSSH PEM key.
- **Path / المسار:** المجلّد المراد استعراضه، الافتراضي `.` (الدليل الرئيسي للجلسة) · the directory to list, default `.` (the session home).

## المخرجات · Outputs
**بالعربي:** قائمة بمحتويات المجلّد، تظهر فيها المجلّدات أولًا (بأيقونة مجلّد) ثم الملفات مرتّبة أبجديًا، مع حجم كل ملف. النقر على مجلّد يدخله؛ والنقر على ملف يُنزّله إلى مجلّد مؤقّت ويظهر زر مشاركة (`ShareLink`). يوجد زر "للأعلى" للرجوع للمجلّد الأب. أسماء `.` و `..` تُستبعَد من العرض.

**English:** A directory listing with folders shown first (folder icon) then files sorted alphabetically, each with its size. Tapping a folder navigates into it; tapping a file downloads it to a temporary folder and shows a share button (`ShareLink`). An "up" button returns to the parent directory. The `.` and `..` entries are filtered out.

## مثال تشغيل · Worked example
**بالعربي:** المضيف `test.rebex.net`، المنفذ `22`، المستخدم `demo`، كلمة المرور `password`، المسار `.`. المتوقّع: قائمة تحوي مجلّد `pub` وملفًا مثل `readme.txt`. الدخول إلى `pub/example` ثم النقر على `ReadMe.txt` ينزّل الملف ويتيح مشاركته.

**English:** Host `test.rebex.net`, port `22`, user `demo`, password `password`, path `.`. Expected: a listing containing a `pub` folder and a file like `readme.txt`. Navigating into `pub/example` then tapping `ReadMe.txt` downloads the file and offers to share it.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** كل عملية (استعراض أو تنزيل) تفتح اتصالًا جديدًا وتغلقه بعد الانتهاء. التنزيل محدود بنحو 8 ميغابايت لكل ملف. يرث كل قيود عميل SSH: فقط تبادل `curve25519-sha256` وتشفير AES-GCM، ومصادقة مفتاح `ed25519` فقط، وإصدار SFTP رقم 3. رغم أن SFTP آمن ومشفّر، تذكّر أن الملفات المنزّلة تُخزَّن مؤقتًا على الجهاز. بيانات الاعتماد لا تغادر الجهاز إلا نحو الخادم المستهدف.

**English:** Each operation (list or download) opens a fresh connection and closes it when done. Downloads are capped at roughly 8 MB per file. It inherits all SSH client constraints: only `curve25519-sha256` exchange and AES-GCM encryption, `ed25519` key auth only, and SFTP version 3. Although SFTP is secure and encrypted, remember that downloaded files are stored temporarily on the device. Credentials never leave the device except toward the target server.
