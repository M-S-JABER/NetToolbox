# DNS Lookup · استعلام DNS

> **Category / التصنيف:** DNS & Domains / DNS والنطاقات  
> **Tool ID:** `dns-lookup`

---

## نظرة عامة · Overview
**بالعربي:** أداة تُرسل استعلام DNS خامًا مباشرة إلى خادم أسماء تختاره عبر بروتوكول UDP على المنفذ `53`، وتفكّ ترميز الإجابة بنفسها. تبني حزمة الاستعلام وتحلّل الرد باستخدام مُرمِّز `DNSMessage` المكتوب داخل التطبيق، دون الاعتماد على مُحلِّل النظام.

**English:** Sends a raw DNS query directly to a name server of your choice over UDP on port `53`, and decodes the answer itself. It builds the query packet and parses the reply using the app's in-house `DNSMessage` codec, bypassing the system resolver.

## كيف تعمل · How it works
**بالعربي:** يشفّر `DNSMessage.encodeQuery` اسم النطاق ونوع السجل في حزمة DNS بصيغة wire-format (بمعرّف ثابت `0x1234`). تُرسَل الحزمة عبر `UDPExchange.request` إلى `host:53` مع مهلة `5` ثوانٍ باستخدام مقبس UDP قصير العمر. عند وصول الرد يفكّه `DNSMessage.decodeAnswers` إلى قائمة سجلات. الاتصال بالمنفذ `53` UDP مباشر إلى الخادم المُدخَل — ليس DNS-over-HTTPS ولا عبر مُحلِّل نظام التشغيل.

**English:** `DNSMessage.encodeQuery` encodes the domain name and record type into a wire-format DNS packet (with a fixed ID `0x1234`). The packet is sent via `UDPExchange.request` to `host:53` with a `5`-second timeout over a short-lived UDP socket. When the reply arrives, `DNSMessage.decodeAnswers` parses it into records. This is direct UDP to port `53` on the entered server — not DNS-over-HTTPS and not the OS resolver.

## المدخلات · Inputs
- **Name / الاسم:** اسم النطاق للاستعلام عنه، مثل `example.com` · the domain name to query.
- **Type / النوع:** نوع السجل، من: `A`, `NS`, `CNAME`, `SOA`, `PTR`, `MX`, `TXT`, `AAAA`.
- **Server / الخادم:** عنوان IP لخادم DNS، الافتراضي `1.1.1.1` · IP address of the DNS server (default `1.1.1.1`).

## المخرجات · Outputs
**بالعربي:** قائمة سجلات الإجابة؛ كل صف يعرض نوع السجل، وقيمته (قابلة للنسخ)، ومدة الصلاحية `TTL` بالثواني. عند عدم وجود سجلات تظهر رسالة مناسبة، وعند الفشل تظهر رسالة الخطأ.

**English:** A list of answer records; each row shows the record type, its value (copyable), and the `TTL` in seconds. If there are no records, a suitable message is shown; on failure, the error message is displayed.

## مثال تشغيل · Worked example
**بالعربي:** الاسم `example.com`، النوع `A`، الخادم `1.1.1.1`. الناتج المتوقّع: سجل `A` بقيمة مثل `93.184.215.14` مع `TTL 3600s`.

**English:** Name `example.com`, type `A`, server `1.1.1.1`. Expected output: an `A` record with a value like `93.184.215.14` and `TTL 3600s`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** يتطلّب أن يسمح مشغّل شبكتك بحركة UDP على المنفذ `53` إلى خادم مخصّص؛ بعض الشبكات تحجب DNS الخارج. الاستعلام غير مشفّر ويمكن مراقبته على الشبكة (استخدم أداة DoH للتشفير). المعرّف ثابت لأن كل استعلام يستخدم مقبسًا مستقلاً قصير العمر.

**English:** Requires your network to allow UDP traffic on port `53` to a custom server; some networks block outbound DNS. The query is unencrypted and observable on the network (use the DoH tool for encryption). The fixed transaction ID is safe because each query uses its own short-lived socket.
