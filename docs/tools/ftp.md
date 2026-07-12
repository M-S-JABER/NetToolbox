# FTP Directory Listing · استعراض مجلّدات FTP

> **Category / التصنيف:** Professional / احترافي  
> **Tool ID:** `ftp`

---

## نظرة عامة · Overview
**بالعربي:** أداة FTP بسيطة تتصل بخادم، تسجّل الدخول، وتستعرض محتويات مجلّد عبر وضع سلبي (passive mode). مفيدة لفحص خوادم FTP والتأكد من صلاحيات الدخول وقراءة قوائم الملفات. التنفيذ أصلي بالكامل بدون مكتبات خارجية. FTP نصّي عادي فقط (للنقل المشفّر استخدم SFTP الذي يعتمد على SSH).

**English:** A simple FTP tool that connects to a server, logs in, and lists a directory's contents over passive mode. Useful for probing FTP servers, confirming login credentials, and reading file listings. Fully native implementation with no external libraries. Plaintext FTP only (for encrypted transfer use SFTP, which is built on SSH).

## كيف تعمل · How it works
**بالعربي:** الأداة تفتح اتصال TCP للتحكّم (control connection) على المنفذ `21` افتراضيًا وتقرأ لافتة الترحيب `220`. ثم ترسل أوامر FTP النصّية: `USER` و `PASS` لتسجيل الدخول (رمز `≥500` يعني فشل الدخول)، ثم `TYPE A` (وضع ASCII)، ثم `PASV` لطلب الوضع السلبي. تُحلَّل استجابة `227 Entering Passive Mode (h1,h2,h3,h4,p1,p2)` لاستخراج عنوان ومنفذ قناة البيانات (المنفذ = `p1×256 + p2`)، ويُفتح اتصال بيانات ثانٍ إليه. يُرسَل أمر `LIST` (مع المسار إن وُجد) وتُقرأ القائمة من قناة البيانات، ثم تُقرأ استجابة `226` (اكتمال النقل) وتُغلَق الاتصالات. كل الأوامر تنتهي بـ `\r\n`.

**English:** The tool opens a control TCP connection on port `21` by default and reads the `220` greeting. It then sends text FTP commands: `USER` and `PASS` to log in (a code `≥500` means login failure), then `TYPE A` (ASCII mode), then `PASV` to request passive mode. The `227 Entering Passive Mode (h1,h2,h3,h4,p1,p2)` response is parsed to extract the data-channel host and port (port = `p1×256 + p2`), and a second data connection is opened to it. A `LIST` command (with the path if given) is sent and the listing is read from the data channel, then the `226` (transfer complete) response is read and the connections are closed. Every command ends with `\r\n`.

## المدخلات · Inputs
- **Host / المضيف:** اسم النطاق أو IP لخادم FTP · Hostname or IP of the FTP server.
- **Port / المنفذ:** افتراضيًا `21` · Defaults to `21`.
- **User / المستخدم:** الافتراضي `anonymous` · Defaults to `anonymous`.
- **Password / كلمة المرور:** الافتراضي `anonymous@` (للدخول المجهول) · Defaults to `anonymous@` (for anonymous login).
- **Path / المسار:** المجلّد المراد استعراضه؛ إن تُرك فارغًا يُستخدَم `LIST` على المجلّد الحالي · the directory to list; if empty, `LIST` runs on the current directory.

## المخرجات · Outputs
**بالعربي:** نص قائمة الملفات كما يعيده الخادم (عادةً بصيغة `ls -l`: صلاحيات، مالك، حجم، تاريخ، اسم). عند فراغ القائمة تظهر رسالة "لا يوجد محتوى". عند فشل الاتصال أو الدخول أو الوضع السلبي تظهر بطاقة خطأ موضّحة.

**English:** The file listing text as returned by the server (usually `ls -l` style: permissions, owner, size, date, name). If the listing is empty, an "empty" message is shown. On connection, login, or passive-mode failure, a descriptive error card appears.

## مثال تشغيل · Worked example
**بالعربي:** المضيف `ftp.gnu.org`، المنفذ `21`، المستخدم `anonymous`، كلمة المرور `anonymous@`، المسار `/gnu`. المتوقّع: قائمة بأسطر مثل `drwxr-xr-x 2 ftp ftp 4096 Jan 01 2024 bash` تعرض المجلّدات والملفات تحت `/gnu`.

**English:** Host `ftp.gnu.org`, port `21`, user `anonymous`, password `anonymous@`, path `/gnu`. Expected: a listing of lines like `drwxr-xr-x 2 ftp ftp 4096 Jan 01 2024 bash` showing folders and files under `/gnu`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** FTP نصّي غير مشفّر — اسم المستخدم وكلمة المرور وكل البيانات تُرسَل بوضوح. لا تستخدمه ببيانات اعتماد حسّاسة على شبكات غير موثوقة؛ فضّل SFTP. الأداة تدعم الوضع السلبي فقط (لا وضع نشط)، وتقتصر على استعراض القوائم (لا رفع/تنزيل ملفات فردية). المهلة `8` ثوانٍ لكل مرحلة. بيانات الاعتماد تبقى على الجهاز ولا تُرسَل إلا للخادم المستهدف.

**English:** FTP is plaintext and unencrypted — the username, password, and all data are sent in the clear. Do not use it with sensitive credentials over untrusted networks; prefer SFTP. The tool supports passive mode only (no active mode) and is limited to directory listing (no per-file upload/download). The timeout is `8` seconds per stage. Credentials stay on the device and are only sent to the target server.
