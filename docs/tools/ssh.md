# SSH Client · عميل SSH

> **Category / التصنيف:** Professional / احترافي  
> **Tool ID:** `ssh`

---

## نظرة عامة · Overview
**بالعربي:** عميل SSH-2 كامل مكتوب من الصفر داخل التطبيق، يتيح لك تشغيل أمر واحد على خادم بعيد أو فتح جلسة صدفة (shell) تفاعلية سطرية. يدعم المصادقة بكلمة المرور أو بمفتاح `ed25519` خاص، ويعرض بصمة مفتاح المضيف وحالة التحقق منها. التنفيذ يعتمد كليًا على `CryptoKit` بدون أي مكتبة SSH خارجية.

**English:** A full from-scratch SSH-2 client built into the app that lets you run a single command on a remote server or open an interactive line-oriented shell. It supports password or private `ed25519` key authentication and displays the host key fingerprint and its verification status. The implementation relies entirely on `CryptoKit` with no external SSH library.

## كيف تعمل · How it works
**بالعربي:** الأداة تتصل عبر TCP بالمنفذ `22` افتراضيًا. البروتوكول هو SSH-2 حقيقي: تبادل نسخة `SSH-2.0-NetToolbox_1.0`، ثم `KEXINIT`، وتبادل مفاتيح `curve25519-sha256` (Curve25519 عبر `CryptoKit`)، ويتم تشفير القناة بـ `aes256-gcm@openssh.com` (مع `aes128-gcm@openssh.com` كخيار). يُتحقَّق من توقيع مفتاح المضيف على تجزئة التبادل (exchange hash)، ثم تُشتق مفاتيح الجلسة الأربعة. تجري المصادقة بطلب `password` أو `publickey` (مع توقيع `ssh-ed25519`). في وضع الأمر تُفتح قناة `session` ويُرسَل طلب `exec`؛ وفي وضع الصدفة يُطلب `pty-req` (نوع `xterm`، ‏`80×24`) ثم `shell`. كل التأطير (packet framing) والتشفير المصادَق عليه (AES-GCM) مُنفَّذ يدويًا. لا توجد تبعيات خارجية.

**English:** The tool connects over TCP to port `22` by default. The protocol is real SSH-2: it exchanges the version banner `SSH-2.0-NetToolbox_1.0`, sends `KEXINIT`, performs `curve25519-sha256` key exchange (Curve25519 via `CryptoKit`), and encrypts the channel with `aes256-gcm@openssh.com` (with `aes128-gcm@openssh.com` as an alternate). The host key signature is verified over the exchange hash, then the four session keys are derived. Authentication uses a `password` or `publickey` request (with an `ssh-ed25519` signature). In command mode it opens a `session` channel and sends an `exec` request; in shell mode it requests `pty-req` (type `xterm`, `80×24`) then `shell`. All packet framing and authenticated encryption (AES-GCM) are implemented by hand. No external dependencies.

## المدخلات · Inputs
- **Host / المضيف:** اسم النطاق أو عنوان IP للخادم · Hostname or IP of the server.
- **Port / المنفذ:** افتراضيًا `22` · Defaults to `22`.
- **Username / اسم المستخدم:** حساب الدخول على الخادم · The login account on the server.
- **Auth mode / نمط المصادقة:** كلمة مرور أو مفتاح خاص · Password or private key.
  - **Password / كلمة المرور:** تُرسَل عبر طلب `password` (داخل القناة المشفّرة) · sent via a `password` request (inside the encrypted channel).
  - **Private key / المفتاح الخاص:** مفتاح `ed25519` بصيغة OpenSSH PEM يُلصَق في المحرِّر · an `ed25519` key in OpenSSH PEM format pasted into the editor.
- **Mode / الوضع:** `command` (أمر واحد) أو `shell` (صدفة تفاعلية) · `command` (one-shot) or `shell` (interactive).
- **Command / الأمر:** الأمر المراد تنفيذه في وضع الأمر، مثل `uname -a` · the command to run in command mode, e.g. `uname -a`.
- **Shell input / إدخال الصدفة:** أسطر تُرسَل حيّة إلى الصدفة في الوضع التفاعلي · lines sent live to the shell in interactive mode.
- **Profiles / الملفات المحفوظة:** يمكن حفظ بيانات الاتصال (مضيف/منفذ/مستخدم/مصادقة) واستعادتها لاحقًا · connection details can be saved and reloaded later.

## المخرجات · Outputs
**بالعربي:** في وضع الأمر تُعرَض بطاقة "مفتاح المضيف" (نوع المفتاح مثل `ssh-ed25519`، والبصمة بصيغة `SHA256:…`، وشارة "مُتحقَّق منه" أو "غير مُتحقَّق منه")، ثم مخرجات الأمر (stdout و stderr مدمجة) مع رمز الخروج `exit-status`. في وضع الصدفة يُعرَض نص متجدد للجلسة حيّة يُحدَّث كلما وصلت بيانات جديدة.

**English:** In command mode a "host key" card is shown (key type such as `ssh-ed25519`, a `SHA256:…` fingerprint, and a "verified" / "unverified" badge), then the command output (stdout and stderr merged) with the `exit-status` exit code. In shell mode a live transcript updates as new data arrives.

## مثال تشغيل · Worked example
**بالعربي:** المضيف `test.rebex.net`، المنفذ `22`، المستخدم `demo`، كلمة المرور `password`، الوضع `command`، الأمر `uname -a`. المتوقّع: نوع مفتاح المضيف `ssh-ed25519`، بصمة مثل `SHA256:oWF1AZAT...`، ثم سطر مخرجات يصف نظام الخادم ورمز خروج `0`.

**English:** Host `test.rebex.net`, port `22`, user `demo`, password `password`, mode `command`, command `uname -a`. Expected: host key type `ssh-ed25519`, a fingerprint like `SHA256:oWF1AZAT...`, then an output line describing the server OS and exit status `0`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** يدعم العميل فقط تبادل مفاتيح `curve25519-sha256` وتشفير AES-GCM؛ الخوادم التي لا تعرض هذا المزيج تُرفَض برسالة "لا توجد شيفرة متوافقة". مصادقة المفتاح مقصورة على `ed25519` فقط (لا RSA للمفاتيح الخاصة). البصمة تُحسَب دائمًا، لكن غياب قاعدة "known_hosts" يعني أن حالة "غير مُتحقَّق منه" لا تمنع الاتصال — راجع البصمة يدويًا قبل الوثوق بالخادم. كلمات المرور والمفاتيح تبقى على الجهاز، والملفات المحفوظة تُخزَّن محليًا فقط. مخرجات الأمر محدودة بنحو 4 ميغابايت.

**English:** The client only supports `curve25519-sha256` key exchange and AES-GCM encryption; servers not offering this combination are rejected with a "no matching cipher" error. Key auth is limited to `ed25519` (no RSA private keys). The fingerprint is always computed, but with no `known_hosts` store an "unverified" status does not block the connection — check the fingerprint manually before trusting a server. Passwords and keys stay on the device, and saved profiles are stored locally only. Command output is capped at roughly 4 MB.
