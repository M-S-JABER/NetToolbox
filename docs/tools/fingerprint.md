# Service Fingerprint · بصمة الخدمة

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `fingerprint`

---

## نظرة عامة · Overview
**بالعربي:** أداة بصمة الخدمة تفتح اتصال TCP مباشرًا بالمضيف والمنفذ اللذين تحددهما، وتقرأ الـ banner (الرسالة الترحيبية) التي تعلنها الخدمة، ثم تستنتج نوع الخدمة والمنتج عبر مطابقة أنماط معروفة. كل الاستدلال يجري محليًا على الجهاز دون أي خدمة وسيطة خارجية.
**English:** The Service Fingerprint tool opens a direct TCP connection to the host and port you specify, reads the banner the service announces, and heuristically infers the service type and product by pattern-matching. All identification runs locally on the device with no third-party intermediary.

## كيف تعمل · How it works
**بالعربي:** تتصل الأداة عبر `TCPConnection` بالمضيف على المنفذ المطلوب (مهلة 6 ثوانٍ). إذا كان المنفذ ضمن منافذ HTTP الشائعة (`80`، `443`، `8000`، `8008`، `8080`، `8443`) فإنها ترسل مسبار `GET / HTTP/1.0` لاستدراج ترويسات الاستجابة؛ وإلا تكتفي بقراءة ما تعلنه الخدمة تلقائيًا. عند المنفذين `443` و`8443` يُجرى الاتصال فوق TLS. بعد جمع النص يمرّر إلى `ServiceFingerprint.identify` الذي يطبّق قواعد استدلالية: بادئة `SSH-` تُصنّف SSH وتستخرج اسم البرنامج، ووجود `HTTP/` يُصنّف HTTP ويقرأ ترويسة `Server`، و`220 ... vsftpd/filezilla` يُصنّف FTP، و`esmtp` أو `220 ... smtp` يُصنّف SMTP، و`* OK ... imap` يُصنّف IMAP، و`+OK` يُصنّف POP3، و`redis_version`/`+PONG` يُصنّف Redis، و`mysql`/`mariadb` يُصنّف MySQL. عند عدم التطابق تعود الأداة إلى اسم الخدمة المعروف للمنفذ من `PortDatabase`.
**English:** The tool connects via `TCPConnection` to the host on the requested port (6-second timeout). If the port is a common HTTP port (`80`, `443`, `8000`, `8008`, `8080`, `8443`) it sends a `GET / HTTP/1.0` probe to elicit response headers; otherwise it just reads whatever the service announces. Ports `443` and `8443` connect over TLS. The collected text is passed to `ServiceFingerprint.identify`, which applies heuristics: an `SSH-` prefix classifies SSH and extracts the software string, `HTTP/` classifies HTTP and reads the `Server` header, `220 ... vsftpd/filezilla` classifies FTP, `esmtp` or `220 ... smtp` classifies SMTP, `* OK ... imap` classifies IMAP, `+OK` classifies POP3, `redis_version`/`+PONG` classifies Redis, and `mysql`/`mariadb` classifies MySQL. On no match it falls back to the port's well-known service name from `PortDatabase`.

## المدخلات · Inputs
- **Host / المضيف:** اسم النطاق أو عنوان IP الهدف (مثل `example.com` أو `192.168.1.1`). / Target hostname or IP.
- **Port / المنفذ:** رقم المنفذ TCP (افتراضيًا `22`). / TCP port number (defaults to `22`).

## المخرجات · Outputs
**بالعربي:** بطاقة نتيجة تعرض: **الخدمة** (Service) المستنتجة مثل `SSH`، و**المنتج** (Product) مثل `OpenSSH_8.9p1 Ubuntu-3` إن توفر، و**النص الخام للـ banner** كاملًا قابلًا للنسخ. عند فشل الاتصال أو منفذ غير صالح تظهر رسالة خطأ.
**English:** A result card showing the inferred **Service** (e.g. `SSH`), the **Product** (e.g. `OpenSSH_8.9p1 Ubuntu-3`) when available, and the full raw **banner** text (selectable). On connection failure or an invalid port an error message is shown.

## مثال تشغيل · Worked example
**بالعربي:** المدخل `example.com` مع المنفذ `22`. تقرأ الأداة الـ banner `SSH-2.0-OpenSSH_8.9p1 Ubuntu-3`، فتعرض الخدمة `SSH` والمنتج `OpenSSH_8.9p1 Ubuntu-3`.
**English:** Input `example.com` with port `22`. The tool reads the banner `SSH-2.0-OpenSSH_8.9p1 Ubuntu-3` and reports service `SSH`, product `OpenSSH_8.9p1 Ubuntu-3`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** الاستدلال تقريبي ويعتمد على ما تكشفه الخدمة؛ الخدمات المهيّأة لإخفاء الـ banner قد تُصنَّف كـ `unknown`. الاتصال مباشر من جهازك إلى الهدف، لذا استخدمها فقط مع أنظمة تملك صلاحية فحصها. لا تتطلب أذونات خاصة على iOS، لكن جدران الحماية قد تحجب المنافذ غير الشائعة.
**English:** Identification is heuristic and depends on what the service exposes; services that suppress banners may be labeled `unknown`. The connection is made directly from your device to the target, so only probe systems you are authorized to test. No special iOS permissions are required, but firewalls may block uncommon ports.
