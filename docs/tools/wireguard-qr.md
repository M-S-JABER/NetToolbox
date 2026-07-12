# WireGuard QR Generator · مولّد رمز QR لـ WireGuard

> **Category / التصنيف:** Local Network / الشبكة المحلية  
> **Tool ID:** `wireguard-qr`

---

## نظرة عامة · Overview
**بالعربي:** يبني هذا الأداة ملف إعداد نفق WireGuard (VPN) ويحوّله إلى رمز QR يستطيع تطبيق WireGuard الرسمي استيراده بمجرد مسحه. يولّد أزواج المفاتيح محليًّا باستخدام منحنى Curve25519 عبر CryptoKit — نفس المنحنى الذي يستخدمه WireGuard — فلا حاجة لأي أدوات خارجية. الإعداد لا يغادر الجهاز إلا إذا شاركته أنت.
**English:** This tool builds a WireGuard tunnel (VPN) configuration and turns it into a QR code that the official WireGuard app can import simply by scanning. It generates key pairs locally using the Curve25519 curve via CryptoKit — the same curve WireGuard uses — so no external tooling is needed. The configuration never leaves the device unless you share it.

## كيف تعمل · How it works
**بالعربي:** هذا مولّد محلي بحت ولا يُجري أي اتصال شبكي. يُجمِّع نص ملف `.conf` من حقول النفق بقسمين: `[Interface]` (المفتاح الخاص، العنوان، DNS) و`[Peer]` (مفتاح الخادم العام، المفتاح المشترك مسبقًا، نقطة النهاية، العناوين المسموحة، الإبقاء الدوري). الحقول الفارغة تُحذف. يولّد المفاتيح عبر `Curve25519.KeyAgreement.PrivateKey` ويرمّزها Base64 كما يتوقّع WireGuard، ويشتقّ المفتاح العام من المفتاح الخاص المُلصق تلقائيًّا (وهو ما تُسجّله على الخادم). ثم يُرمَّز نص الإعداد كاملًا إلى رمز QR عبر CoreImage. المفتاح العام المشتقّ قابل للنسخ، والإعداد النهائي قابل للنسخ والمشاركة.
**English:** This is a purely local generator and performs no networking. It assembles a `.conf` file string from the tunnel fields in two sections: `[Interface]` (private key, address, DNS) and `[Peer]` (server public key, pre‑shared key, endpoint, allowed IPs, persistent keepalive). Empty fields are omitted. It generates keys via `Curve25519.KeyAgreement.PrivateKey` encoded as Base64 as WireGuard expects, and derives the public key from a pasted private key automatically (this is what you register on the server). The full configuration text is then encoded to a QR code via CoreImage. The derived public key is copyable, and the final configuration is copyable and shareable.

## المدخلات · Inputs
**بالعربي:** قسم **الواجهة [Interface]:**
- **المفتاح الخاص (Private Key):** إلزامي — يمكن لصقه أو توليده بزر «توليد» الذي ينشئ زوجًا جديدًا. يُشتقّ منه المفتاح العام تلقائيًّا ويُعرض للنسخ.
- **العنوان (Address):** افتراضيًّا `10.0.0.2/32`.
- **DNS:** افتراضيًّا `1.1.1.1`.

قسم **النظير [Peer]:**
- **المفتاح العام للنظير (Peer Public Key):** إلزامي — المفتاح العام لخادم VPN.
- **المفتاح المشترك مسبقًا (PresharedKey):** اختياري لطبقة تشفير إضافية.
- **نقطة النهاية (Endpoint):** إلزامية — عنوان الخادم ومنفذه مثل `vpn.example.com:51820`.
- **العناوين المسموحة (AllowedIPs):** افتراضيًّا `0.0.0.0/0, ::/0` (توجيه كل الحركة).
- **الإبقاء الدوري (PersistentKeepalive):** افتراضيًّا `25` ثانية.

لا يظهر رمز QR حتى تُملأ الحقول الثلاثة الإلزامية (المفتاح الخاص، مفتاح النظير العام، نقطة النهاية).
**English:** **[Interface]** section:
- **Private Key:** required — paste it or use the "Generate" button to create a fresh pair. The public key is derived from it automatically and shown for copying.
- **Address:** default `10.0.0.2/32`.
- **DNS:** default `1.1.1.1`.

**[Peer]** section:
- **Peer Public Key:** required — the VPN server's public key.
- **PresharedKey:** optional extra encryption layer.
- **Endpoint:** required — the server's host and port such as `vpn.example.com:51820`.
- **AllowedIPs:** default `0.0.0.0/0, ::/0` (route all traffic).
- **PersistentKeepalive:** default `25` seconds.

The QR code does not appear until the three required fields (private key, peer public key, endpoint) are filled.

## المخرجات · Outputs
**بالعربي:**
- **المفتاح العام المشتقّ:** يُعرض للنسخ فور إدخال مفتاح خاص صالح — سجّله على الخادم.
- **رمز QR:** صورة على خلفية بيضاء تمثّل ملف `.conf`، يمسحها تطبيق WireGuard لاستيراد النفق.
- **نص الإعداد:** يُعرض كاملًا مع أزرار نسخ ومشاركة.
**English:**
- **Derived public key:** shown for copying as soon as a valid private key is entered — register it on the server.
- **QR code:** a white‑background image representing the `.conf` file, which the WireGuard app scans to import the tunnel.
- **Configuration text:** shown in full with copy and share buttons.

## مثال تشغيل · Worked example
**بالعربي:** تضغط «توليد» فيظهر مفتاح خاص جديد ويُعرض مفتاحه العام المشتقّ (تنسخه لتسجّله على الخادم). تلصق مفتاح النظير العام `xTIBA5rboUvnH...=`، وتكتب نقطة النهاية `vpn.example.com:51820`، وتترك بقيّة الحقول على قيمها الافتراضية. يظهر رمز QR ونص الإعداد:
```
[Interface]
PrivateKey = <المولّد>
Address = 10.0.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = xTIBA5rboUvnH...=
Endpoint = vpn.example.com:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```
تفتح تطبيق WireGuard وتضيف نفقًا بمسح الرمز.
**English:** You tap "Generate" and a new private key appears with its derived public key shown (you copy it to register on the server). You paste the peer public key `xTIBA5rboUvnH...=`, enter the endpoint `vpn.example.com:51820`, and leave the rest at defaults. The QR code and config text appear:
```
[Interface]
PrivateKey = <generated>
Address = 10.0.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = xTIBA5rboUvnH...=
Endpoint = vpn.example.com:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```
You open the WireGuard app and add a tunnel by scanning the code.

## ملاحظات وقيود · Notes & limitations
**بالعربي:**
- هذه الأداة مولّد محلي بالكامل ولا تتصل بالشبكة إطلاقًا، لذا **لا تتطلب صلاحية «الشبكة المحلية»** ولا أي أذونات شبكية. (أدوات التطبيق الأخرى التي تخاطب الشبكة تتطلبها؛ لتفعيلها: **الإعدادات ← NetToolbox ← الشبكة المحلية**.)
- الأداة تُنشئ إعداد العميل فقط ولا تُنشئ النفق ولا تتصل بالـ VPN؛ الاتصال الفعلي يتم في تطبيق WireGuard الرسمي بعد الاستيراد.
- المفتاح الخاص حسّاس — رمز QR يحتوي عليه؛ لا تشاركه إلا مع الجهاز الذي سيستخدم النفق.
- يجب أن يكون مفتاح النظير العام ونقطة النهاية صحيحين ومتطابقين مع إعداد الخادم كي يعمل النفق.
**English:**
- This tool is a fully local generator and does no networking at all, so it **does not require the Local Network permission** or any network access. (The app's other tools that touch the network do; enable it via **Settings ← NetToolbox ← Local Network**.)
- The tool only builds the client configuration; it does not create the tunnel or connect the VPN — the actual connection happens in the official WireGuard app after import.
- The private key is sensitive — the QR code contains it; only share it with the device that will use the tunnel.
- The peer public key and endpoint must be correct and match the server's configuration for the tunnel to work.
