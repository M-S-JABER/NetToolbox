# Backup & Restore · النسخ الاحتياطي والاستعادة

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `backup`

---

## نظرة عامة · Overview
**بالعربي:** تصدّر هذه الأداة بياناتك المحفوظة على الجهاز إلى ملف JSON قابل للمشاركة، وتعيد استيرادها لاحقًا — مع خيار تشفير الملف بكلمة مرور. تشمل النسخة: المضيفين المحفوظين، ملفات SSH، الكاميرات، وسجل اختبارات السرعة.
**English:** This tool exports your on-device saved data to a shareable JSON file and restores it later — with an option to encrypt the file with a password. A backup includes: saved hosts, SSH profiles, cameras, and speed-test history.

## كيف تعمل · How it works
**بالعربي:** يجمع التطبيق البيانات في بنية `AppBackup` (إصدار `version = 1`، مع طابع زمني `exportedAt`) ويُرمّزها بـ `JSONEncoder` منسّقًا ومُرتّب المفاتيح. بدون تشفير يُحفَظ الملف باسم `NetToolbox-backup.json`. مع تفعيل التشفير يُمرَّر المحتوى عبر `BackupCrypto.encrypt(data, password:)` ويُحفَظ باسم `NetToolbox-backup.ntbackup`. عند الاستيراد يُكتشَف تلقائيًا إن كان الملف مشفّرًا (`BackupCrypto.isEncrypted`)؛ فإن كان كذلك يُطلَب منك كلمة المرور لفكّه عبر `BackupCrypto.decrypt`. الاستعادة **تستبدل** البيانات الحالية بالكامل (`replaceAll`). كل ذلك محلي على الجهاز — لا شبكة ولا خادم.
**English:** The app gathers data into an `AppBackup` struct (`version = 1`, with an `exportedAt` timestamp) and encodes it with a pretty-printed, sorted-keys `JSONEncoder`. Unencrypted, the file is saved as `NetToolbox-backup.json`. With encryption on, the content is passed through `BackupCrypto.encrypt(data, password:)` and saved as `NetToolbox-backup.ntbackup`. On import the file is auto-detected as encrypted (`BackupCrypto.isEncrypted`); if so you're prompted for the password to decrypt via `BackupCrypto.decrypt`. Restore **replaces** the current data entirely (`replaceAll`). All of this is local to the device — no network, no server.

## المدخلات · Inputs
**بالعربي:**
- **مفتاح "تشفير":** يفعّل حقل كلمة المرور للتصدير المشفّر.
- **كلمة مرور التصدير:** مطلوبة عند التشفير (زر التصدير معطّل حتى تُدخلها).
- **زر استيراد:** يفتح منتقي ملفات (`.json` أو `.data`).
- **كلمة مرور الاستيراد:** تُطلَب فقط للملفات المشفّرة.
**English:**
- **Encrypt toggle:** enables the password field for an encrypted export.
- **Export password:** required when encrypting (the export button is disabled until it's entered).
- **Import button:** opens a file picker (`.json` or `.data`).
- **Import password:** requested only for encrypted files.

## المخرجات · Outputs
**بالعربي:** بطاقة المحتويات تعرض عدد كل نوع (مضيفون، SSH، كاميرات، سجل السرعة). بعد التصدير يظهر زر مشاركة للملف الناتج. رسائل نجاح/خطأ تُعرَض في بطاقة (مثل "تمت الاستعادة" أو خطأ كلمة المرور).
**English:** A contents card shows the count of each type (hosts, SSH, cameras, speed history). After export a Share button for the resulting file appears. Success/error messages are shown in a card (e.g. "restore done" or a password error).

## مثال تشغيل · Worked example
**بالعربي:** تفعيل "تشفير"، إدخال كلمة مرور، ثم "تصدير" ← يُنشأ ملف `NetToolbox-backup.ntbackup` يمكن مشاركته. لاحقًا "استيراد" لنفس الملف ← يُطلب إدخال كلمة المرور، وبعد فكّها تُستبدَل البيانات الحالية وتظهر "تمت الاستعادة".
**English:** Turn on Encrypt, enter a password, then Export → a `NetToolbox-backup.ntbackup` file is created to share. Later Import that file → you're prompted for the password, and after decryption the current data is replaced and "restore done" appears.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** الاستعادة تستبدل كل بياناتك الحالية (لا دمج) — انتبه. إذا نسيت كلمة مرور نسخة مشفّرة فلا يمكن استعادتها. تُحفَظ الملفات في مجلد مستندات التطبيق على الجهاز؛ الأسرار الحسّاسة كمفاتيح SSH وبيانات الكاميرات تبقى محميّة. لا يتطلب إنترنت.
**English:** Restore replaces all your current data (no merge) — be careful. If you forget an encrypted backup's password, it cannot be recovered. Files are saved in the app's Documents directory on-device; sensitive secrets like SSH keys and camera credentials stay protected. No internet required.
