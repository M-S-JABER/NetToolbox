# SNMP GET / Walk · استعلام SNMP (GET / Walk)

> **Category / التصنيف:** Professional / احترافي  
> **Tool ID:** `snmp`

---

## نظرة عامة · Overview
**بالعربي:** أداة استعلام SNMP تقرأ قيم كائنات الإدارة (OIDs) من الأجهزة الشبكية عبر منفذ UDP رقم `161`. تدعم عملية `GET` لقيمة واحدة و`Walk` (عبر GETNEXT) لتصفّح شجرة فرعية كاملة باستخدام SNMP v2c، إضافةً إلى وضع تجريبي لـ SNMP v3 (authNoPriv).
**English:** An SNMP query tool that reads management object values (OIDs) from network devices over UDP port `161`. It supports `GET` for a single value and `Walk` (via GETNEXT) to traverse a whole subtree using SNMP v2c, plus a beta SNMP v3 (authNoPriv) mode.

## كيف تعمل · How it works
**بالعربي:** في وضع v2c، تُرمَّز رسالة SNMP بترميز BER بواسطة كوديك `SNMPMessage` وتُرسَل عبر UDP (بمهلة 5 ثوانٍ) عبر `UDPExchange`. عملية `GET` تطلب OID محدداً وتعيد varbind واحداً (OID، النوع، القيمة). عملية `Walk` تُصدر طلبات `GETNEXT` متتالية بدءاً من OID المُعطى، وتتوقف عند مغادرة الشجرة الفرعية أو توقف التقدّم، بحدّ أقصى 256 خطوة. في وضع v3 (تجريبي) يُستخدم `SNMPv3Service` بأمان المستخدم (USM) في مستوى authNoPriv (مصادقة بدون تشفير) عبر GET فقط.
**English:** In v2c mode, the SNMP message is BER-encoded by the `SNMPMessage` codec and sent over UDP (5-second timeout) via `UDPExchange`. `GET` requests a specific OID and returns a single varbind (OID, type, value). `Walk` issues successive `GETNEXT` requests starting from the given OID, stopping when it leaves the subtree or stops advancing, capped at 256 steps. In v3 (beta) mode, `SNMPv3Service` is used with User Security Model (USM) at the authNoPriv level (authentication, no encryption) over GET only.

## المدخلات · Inputs
- **الإصدار / Version:** `v2c` أو `v3` (تجريبي) · `v2c` or `v3` (beta).
- **المضيف / Host:** عنوان الجهاز · Device address.
- **المنفذ / Port:** الافتراضي `161` (منفذ SNMP القياسي) · Default `161` (standard SNMP port).
- **المجتمع / Community (v2c):** سلسلة المجتمع، الافتراضي `public` · The community string, default `public`.
- **OID:** معرّف الكائن، الافتراضي `1.3.6.1.2.1.1.1.0` (sysDescr) · The object identifier, default `1.3.6.1.2.1.1.1.0` (sysDescr).
- **الوضع / Mode (v2c):** `get` أو `walk` · `get` or `walk`.
- **حقول v3:** اسم المستخدم، كلمة مرور المصادقة، وبروتوكول المصادقة (SHA/MD5) · v3 fields: username, auth password, and auth protocol (SHA/MD5).

**بالعربي:** إعدادات جاهزة (Presets) تملأ حقل OID: `sysDescr`، `sysName`، `sysUpTime`، `system` (الشجرة)، `interfaces`.
**English:** Presets fill the OID field: `sysDescr`, `sysName`, `sysUpTime`, `system` (the subtree), `interfaces`.

## المخرجات · Outputs
**بالعربي:** لنتيجة `GET`: بطاقة تعرض OID المُرجَع، نوع القيمة (مثل OCTET STRING، Integer، TimeTicks)، والقيمة القابلة للنسخ. لنتيجة `Walk`: قائمة أزواج OID→قيمة لكل عناصر الشجرة الفرعية. عند الخطأ تظهر رسالة.
**English:** For `GET`: a card showing the returned OID, the value type (e.g. OCTET STRING, Integer, TimeTicks), and the copyable value. For `Walk`: a list of OID→value pairs for every element of the subtree. On error a message is shown.

## مثال تشغيل · Worked example
**بالعربي:** الإدخال: المضيف `192.168.1.1`، المجتمع `public`، OID `1.3.6.1.2.1.1.1.0`، الوضع `get`. النتيجة:
`OID: 1.3.6.1.2.1.1.1.0`، `Type: OCTET STRING`، `Value: MikroTik RouterOS 7.15.2 (hAP ac²)`.
مع الوضع `walk` على `1.3.6.1.2.1.2.2.1.2` (interfaces) تُسرَد أسماء الواجهات: `ether1`، `ether2`، `wlan1` …
**English:** Input: host `192.168.1.1`, community `public`, OID `1.3.6.1.2.1.1.1.0`, mode `get`. Result:
`OID: 1.3.6.1.2.1.1.1.0`, `Type: OCTET STRING`, `Value: MikroTik RouterOS 7.15.2 (hAP ac²)`.
With mode `walk` on `1.3.6.1.2.1.2.2.1.2` (interfaces), interface names are listed: `ether1`, `ether2`, `wlan1` …

## ملاحظات وقيود · Notes & limitations
**بالعربي:** v2c ترسل سلسلة المجتمع بنص واضح بلا تشفير؛ استخدمها في شبكة موثوقة. الجهاز يجب أن يسمح بـ SNMP من عنوانك. `Walk` محدود بـ 256 خطوة كحماية. وضع v3 تجريبي ويدعم authNoPriv وGET فقط (لا تشفير خصوصية priv). المهلة 5 ثوانٍ لكل طلب، وUDP لا يضمن الوصول.
**English:** v2c sends the community string in clear text with no encryption; use it on a trusted network. The device must permit SNMP from your address. `Walk` is limited to 256 steps as a safeguard. The v3 mode is beta and supports authNoPriv and GET only (no priv encryption). Each request times out after 5 seconds, and UDP does not guarantee delivery.
