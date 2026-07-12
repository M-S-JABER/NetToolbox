# Subnet Calculator · حاسبة الشبكات الفرعية

> **Category / التصنيف:** Calculators / الحاسبات  
> **Tool ID:** `subnet-calculator`

---

## نظرة عامة · Overview
**بالعربي:** حاسبة شبكات فرعية شاملة لعنوان `IPv4` أو `IPv6`. تُدخل العنوان مع القناع (Prefix أو Subnet Mask) فتُخرج عنوان الشبكة وعنوان البث وأول وآخر مضيف صالح وعدد المضيفين وأقنعة البتات، إضافة إلى فئة العنوان ونطاقه (خاص/عام/loopback…). موجّهة لمهندسي الشبكات والطلاب لفهم بنية أي شبكة فرعية بسرعة.
**English:** A full subnet calculator for an `IPv4` or `IPv6` address. You enter the address plus a mask (prefix length or dotted subnet mask) and it returns the network address, broadcast, first/last usable host, host counts, binary masks, plus the address class and scope (private/public/loopback…). Aimed at network engineers and students who need to break down any subnet quickly.

## كيف تعمل · How it works
**بالعربي:** كل الحسابات تجري عبر `SubnetEngine` وهو منطق رياضي صرف بلا أي إدخال/إخراج شبكي — **يعمل محلياً بالكامل بدون اتصال بالإنترنت**. يُحوّل العنوان إلى قيمة 32-بت (IPv4) عبر عمليات إزاحة بتات، ثم يطبّق القناع (`ip & mask`) لاستخراج الشبكة، و`network | ~mask` لعنوان البث. يدعم حالات خاصة: `/32` مضيف واحد، و`/31` نقطة-إلى-نقطة (RFC 3021) بمضيفين صالحين. القناع المنقّط يجب أن يكون متصلاً (آحاد ثم أصفار) وإلا يُرفض. نمط IPv6 يُكتشف تلقائياً عند وجود `:` في العنوان، ويستخدم ضغط RFC 5952 وتوسيع الـ hextets. لا يعتمد على مكتبات خارجية، فقط `Foundation`.
**English:** All math runs through `SubnetEngine`, pure logic with no network I/O — **runs 100% on-device, no network**. It parses the address into a 32-bit value (IPv4) via bit shifts, then applies the mask (`ip & mask`) for the network and `network | ~mask` for broadcast. Special cases are handled: `/32` is a single host, `/31` is point-to-point (RFC 3021) with two usable hosts. Dotted masks must be contiguous (ones then zeros) or they are rejected. IPv6 mode is auto-detected when the address contains `:`, using RFC 5952 compression and hextet expansion. No external libraries — only `Foundation`.

## المدخلات · Inputs
| Field · الحقل | الوصف · Description |
|---|---|
| `addressInput` | عنوان `IPv4` (مثل `192.168.1.10`) أو `IPv6` (مثل `2001:db8::1`)، ويمكن تضمين البادئة مباشرة مثل `10.0.0.1/24`. IPv4 or IPv6 address; an inline prefix like `10.0.0.1/24` is accepted. |
| `maskInput` | القناع: طول البادئة (`24` أو `/24`) أو قناع منقّط (`255.255.255.0`). فارغاً يُفترض `/24` لـ IPv4 و`/64` لـ IPv6. Prefix length, dotted mask, or empty (defaults `/24` for IPv4, `/64` for IPv6). |

## المخرجات · Outputs
**بالعربي (IPv4):** عنوان الشبكة، البث، أول/آخر مضيف صالح، عدد المضيفين الصالحين، إجمالي العناوين، قناع الشبكة، القناع البدلي (wildcard)، التمثيل الثنائي للعنوان وللقناع، فئة العنوان (A/B/C/D/E)، والنطاق (خاص، عام، loopback، link-local، CGNAT…). لـ IPv6: الشكل المضغوط والموسّع، بادئة الشبكة، نوع العنوان، وأول/آخر عنوان في المدى. تُحفظ العمليات في سجل (History) عبر SwiftData.
**English (IPv4):** Network address, broadcast, first/last usable host, usable host count, total addresses, subnet mask, wildcard mask, binary of address and mask, address class (A/B/C/D/E), and scope (private, public, loopback, link-local, CGNAT…). For IPv6: compressed and expanded forms, network prefix, address type, and first/last address of the range. Calculations are saved to a History log via SwiftData.

## مثال تشغيل · Worked example
**بالعربي:** إدخال `192.168.1.10` مع `24` →
- الشبكة: `192.168.1.0/24`
- البث: `192.168.1.255`
- أول مضيف: `192.168.1.1` · آخر مضيف: `192.168.1.254`
- مضيفون صالحون: `254` · إجمالي: `256`
- القناع: `255.255.255.0` · البدلي: `0.0.0.255`
- الفئة: `C` · النطاق: خاص (Private, RFC 1918)

**English:** Input `192.168.1.10` with `24` →
- Network: `192.168.1.0/24`
- Broadcast: `192.168.1.255`
- First host: `192.168.1.1` · Last host: `192.168.1.254`
- Usable hosts: `254` · Total: `256`
- Mask: `255.255.255.0` · Wildcard: `0.0.0.255`
- Class: `C` · Scope: Private (RFC 1918)

## ملاحظات وقيود · Notes & limitations
**بالعربي:** لا يرسل أي بيانات لأي خادم — كل شيء يُحسب على الجهاز. لا يدعم IPv6 المضمّن بترميز IPv4 (مثل `::ffff:192.168.0.1`). لأعداد العناوين الكبيرة في IPv6 يُعرض التقدير كأس (`2^64`). القناع المنقّط غير المتصل يُرفض برسالة خطأ.
**English:** No data leaves the device — everything is computed locally. IPv4-embedded IPv6 notation (e.g. `::ffff:192.168.0.1`) is not supported. For very large IPv6 ranges the total is shown as a power (`2^64`). Non-contiguous dotted masks are rejected with an error.
