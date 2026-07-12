# SNMP Trap Receiver · مستقبِل مصائد SNMP

> **Category / التصنيف:** Professional / احترافي  
> **Tool ID:** `snmp-trap`

---

## نظرة عامة · Overview
**بالعربي:** مستقبِل لمصائد SNMP (SNMP Traps) يفتح منفذ UDP محلياً وينتظر رسائل المصائد الواردة من الأجهزة الشبكية. لكل مصيدة يفكّ ترميز الإصدار واسم المجتمع (community) بشكل تقريبي ويعرض ملخصاً مع أول 48 بايت بصيغة سِت عشرية. منفذ SNMP-trap القياسي `162`.
**English:** A receiver for SNMP Traps that binds a local UDP port and waits for inbound trap messages from network devices. For each trap it best-effort decodes the version and community name and shows a summary alongside the first 48 bytes in hex. The standard SNMP-trap port is `162`.

## كيف تعمل · How it works
**بالعربي:** هذه أداة **مستقبِلة**: تربط مقبس UDP على المنفذ المحدد محلياً وتبقى تُصغي حتى ترد رزم — يجب ضبط الأجهزة الشبكية لإرسال مصائدها إلى عنوان IP الخاص بجهازك وهذا المنفذ. عند وصول رزمة، يمشي مفكِّك بسيط عبر ترميز BER (نوع/طول/قيمة) لرسالة SNMP: يقرأ تسلسل `SEQUENCE`، ثم عدد صحيح للإصدار (`0`=v1، `1`=v2c)، ثم سلسلة الأوكتيت الخاصة باسم المجتمع. النتيجة ملخص مثل `SNMP v2c · community: public`. تُحفظ آخر 200 مصيدة، الأحدث في الأعلى.
**English:** This is a **receiver** tool: it binds a local UDP socket on the chosen port and keeps listening until packets arrive — network devices must be configured to send their traps to your device's IP address and this port. On arrival, a simple decoder walks the BER (tag/length/value) encoding of the SNMP message: it reads the outer `SEQUENCE`, then an integer for the version (`0`=v1, `1`=v2c), then the octet string for the community name. The result is a summary such as `SNMP v2c · community: public`. The last 200 traps are kept, newest on top.

## المدخلات · Inputs
- **المنفذ / Port:** المنفذ المحلي الذي يُصغى عليه، الافتراضي `1162` · The local port to listen on, default `1162`.
- **زر الإصغاء/الإيقاف / Listen–Stop button:** يبدأ أو يوقف الاستقبال · Starts or stops receiving.

**بالعربي:** ملاحظة: المنفذ القياسي لمصائد SNMP هو `162`، لكن ربط المنافذ أدنى من 1024 يتطلب صلاحيات مرتفعة عادةً، لذا الافتراضي في التطبيق هو `1162` غير المتميّز؛ وجّه الأجهزة إليه.
**English:** Note: the standard SNMP-trap port is `162`, but binding ports below 1024 usually needs elevated privileges, so the app default is the unprivileged `1162`; point devices at it.

## المخرجات · Outputs
**بالعربي:** قائمة مصائد، كل عنصر يعرض الملخص (الإصدار واسم المجتمع)، عنوان المرسِل، وأول 48 بايت من الرزمة بصيغة سِت عشرية للتفتيش اليدوي. زر لمسح القائمة، وشارة "يُصغي" أثناء التشغيل.
**English:** A list of traps; each row shows the summary (version and community), the sender address, and the first 48 bytes of the packet in hex for manual inspection. A button clears the list, and a "listening" badge shows while active.

## مثال تشغيل · Worked example
**بالعربي:** ابدأ الإصغاء على `1162`، ثم اضبط سويتش لإرسال مصائده إلى `عنوان-الجهاز:1162`. مصيدة واردة تظهر بملخص `SNMP v2c · community: public`، المرسِل `192.168.1.10`، وسطر سِت عشري يبدأ بـ `30 39 02 01 01 04 06 70 75 62 6c 69 63 ...`.
**English:** Start listening on `1162`, then configure a switch to send traps to `device-ip:1162`. An inbound trap appears with summary `SNMP v2c · community: public`, sender `192.168.1.10`, and a hex line beginning `30 39 02 01 01 04 06 70 75 62 6c 69 63 ...`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** فك الترميز أفضل-جهد ويعرض الإصدار والمجتمع فقط، دون تفسير كامل لمتغيّرات المصيدة (varbinds) أو مطابقة OIDs بأسماء. لا يدعم مصائد SNMPv3 المشفّرة/المصادَق عليها. الأداة لا تستقبل شيئاً ما لم تُرسِل الأجهزة إليها، وقد يمنع الجدار الناري الرزم. التخزين في الذاكرة فقط (بحدّ 200).
**English:** Decoding is best-effort and surfaces only version and community, without full parsing of trap varbinds or OID-to-name resolution. It does not support authenticated/encrypted SNMPv3 traps. The tool receives nothing unless devices send to it, and a firewall may block packets. Storage is in-memory only (capped at 200).
