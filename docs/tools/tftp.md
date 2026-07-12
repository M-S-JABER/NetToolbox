# TFTP Download · تنزيل عبر TFTP

> **Category / التصنيف:** Professional / احترافي  
> **Tool ID:** `tftp`

---

## نظرة عامة · Overview
**بالعربي:** عميل قراءة لبروتوكول TFTP (المعرّف في RFC 1350) يُنزّل ملفاً من خادم TFTP عبر منفذ UDP رقم `69`. يعرض حجم الملف ومعاينة نصية لأوله، ويحفظ الملف كاملاً في مجلد المستندات مع إمكانية مشاركته.
**English:** A read client for TFTP (RFC 1350) that downloads a file from a TFTP server over UDP port `69`. It shows the file size and a text preview of its start, and saves the full file to the Documents folder with a Share option.

## كيف تعمل · How it works
**بالعربي:** ترسل الأداة رزمة طلب قراءة (RRQ، رمز العملية 1) تحتوي اسم الملف ووضع النقل `octet` (ثنائي). خصوصية TFTP أن الخادم يردّ من منفذ مصدر جديد يُسمى معرّف النقل (Transfer ID)، لذا تستخدم الأداة مقبس UDP خام غير متصل (`SOCK_DGRAM`) بدلاً من UDP متصل، وتُرسل تأكيد `ACK` لكل كتلة إلى العنوان/المنفذ الذي وردت منه كتلة `DATA`. كل كتلة بيانات بطول 512 بايت؛ وصول كتلة أقصر من 512 بايت يعني نهاية الملف. المهلة 5 ثوانٍ لكل استقبال، والحدّ الأقصى للحجم مليونا بايت (2,000,000).
**English:** The tool sends a Read Request packet (RRQ, opcode 1) carrying the filename and transfer mode `octet` (binary). A TFTP quirk is that the server replies from a *new* source port called the Transfer ID, so the tool uses a raw unconnected UDP socket (`SOCK_DGRAM`) rather than connected UDP, and sends an `ACK` for each block back to the exact address/port the `DATA` block arrived from. Each data block is 512 bytes; a block shorter than 512 bytes marks end-of-file. The receive timeout is 5 seconds per packet, and the maximum size is two million bytes (2,000,000).

## المدخلات · Inputs
- **المضيف / Host:** عنوان خادم TFTP · TFTP server address.
- **المنفذ / Port:** الافتراضي `69` (منفذ TFTP القياسي) · Default `69` (standard TFTP port).
- **اسم الملف / Filename:** المسار/الاسم المطلوب على الخادم مثل `firmware.bin` (تُزال الشرطة المائلة البادئة) · The requested path/name on the server, e.g. `firmware.bin` (a leading slash is stripped).

## المخرجات · Outputs
**بالعربي:** شارة نجاح مع عدد البايتات المنزَّلة، ومعاينة نصية لأول 3000 بايت (مفيدة للملفات النصية مثل ملفات الإعداد)، وزر مشاركة للملف المحفوظ في مجلد المستندات باسمه الأخير.
**English:** A success badge with the number of downloaded bytes, a text preview of the first 3000 bytes (useful for text files such as config files), and a Share button for the file saved into the Documents folder under its last path component.

## مثال تشغيل · Worked example
**بالعربي:** الإدخال: المضيف `192.168.88.1`، المنفذ `69`، اسم الملف `config.rsc`. النتيجة: `downloaded · 2048 bytes` مع معاينة تعرض بداية ملف الإعداد، وزر مشاركة.
**English:** Input: host `192.168.88.1`, port `69`, filename `config.rsc`. Result: `downloaded · 2048 bytes` with a preview showing the start of the config file, plus a Share button.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** يدعم القراءة (RRQ) فقط دون الكتابة (WRQ)، ولا يدعم خيارات RFC 2347 مثل حجم الكتلة المتغير (blksize) أو tsize. لا توجد مصادقة في TFTP. الحدّ الأقصى للتنزيل مليونا بايت، وإن رجّع الخادم رزمة خطأ (رمز العملية 5) تُعرض رسالتها. UDP لا يضمن الوصول.
**English:** It supports reads (RRQ) only, not writes (WRQ), and does not implement RFC 2347 options such as variable block size (blksize) or tsize. TFTP has no authentication. The download cap is two million bytes, and if the server returns an ERROR packet (opcode 5) its message is displayed. UDP does not guarantee delivery.
