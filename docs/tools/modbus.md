# Modbus TCP Reader · قارئ Modbus TCP

> **Category / التصنيف:** Professional / احترافي  
> **Tool ID:** `modbus`

---

## نظرة عامة · Overview
**بالعربي:** أداة تقرأ سجلّات (registers) من جهاز صناعي عبر بروتوكول Modbus TCP. مفيدة لفحص المتحكّمات المنطقية القابلة للبرمجة (PLC) وأجهزة الاستشعار وأنظمة التحكّم الصناعي (SCADA). تدعم قراءة سجلّات الاحتفاظ (holding) وسجلّات الإدخال (input). التنفيذ أصلي بالكامل بدون مكتبات خارجية.

**English:** A tool that reads registers from an industrial device over Modbus TCP. Useful for probing PLCs, sensors, and SCADA / industrial control systems. It supports reading holding registers and input registers. Fully native implementation with no external libraries.

## كيف تعمل · How it works
**بالعربي:** الأداة تفتح اتصال TCP إلى المنفذ `502` افتراضيًا (المنفذ القياسي لـ Modbus TCP). تبني إطار MBAP (رأس التطبيق) الذي يحوي معرّف المعاملة، والبروتوكول `0`، والطول، ومعرّف الوحدة (unit id)، متبوعًا بوحدة البيانات (PDU): رمز الدالة، وعنوان البدء (register address)، والكمّية. الدالة `3` تقرأ سجلّات الاحتفاظ، والدالة `4` تقرأ سجلّات الإدخال. يُرسَل الطلب وتُقرأ الاستجابة وتُحلَّل: إن كان رمز الدالة يحوي البت `0x80` فهي استثناء (exception) ويُعرَض رمزه؛ وإلا تُفكَّك السجلّات كأعداد 16-بت (big-endian، بايتان لكل سجلّ).

**English:** The tool opens a TCP connection to port `502` by default (the standard Modbus TCP port). It builds an MBAP header (transaction id, protocol `0`, length, unit id) followed by the PDU: the function code, the start register address, and the quantity. Function `3` reads holding registers, function `4` reads input registers. The request is sent and the response is read and parsed: if the function code has the `0x80` bit set it is an exception and its code is shown; otherwise the registers are decoded as 16-bit values (big-endian, two bytes per register).

## المدخلات · Inputs
- **Host / المضيف:** عنوان الجهاز الصناعي · the industrial device address.
- **Port / المنفذ:** الافتراضي `502` · Defaults to `502`.
- **Unit / الوحدة:** معرّف الوحدة (slave/unit id)، الافتراضي `1` · the unit/slave id, default `1`.
- **Function / الدالة:** اختيار بين `Holding` (دالة `3`) و `Input` (دالة `4`) · choose between `Holding` (function `3`) and `Input` (function `4`).
- **Address / العنوان:** عنوان أول سجلّ، الافتراضي `0` · the start register address, default `0`.
- **Quantity / الكمّية:** عدد السجلّات المراد قراءتها، الافتراضي `10`، محدودة بين `1` و `125` · the number of registers to read, default `10`, clamped to `1`–`125`.

## المخرجات · Outputs
**بالعربي:** قائمة بالسجلّات المقروءة، كل سطر يعرض: عنوان السجلّ (يبدأ من العنوان المُدخَل ويتزايد)، والقيمة العشرية، والقيمة الستّ عشرية بصيغة `0x00FF`. عند استلام استثناء من الجهاز تظهر رسالة خطأ تحوي رمز الاستثناء (مثل رمز `2` = عنوان بيانات غير صالح).

**English:** A list of the read registers, each line showing: the register address (starting from the entered address and incrementing), the decimal value, and the hexadecimal value as `0x00FF`. If the device returns an exception, an error message with the exception code appears (e.g. code `2` = illegal data address).

## مثال تشغيل · Worked example
**بالعربي:** المضيف `192.168.1.50`، المنفذ `502`، الوحدة `1`، الدالة `Holding` (‏`3`)، العنوان `0`، الكمّية `5`. المتوقّع: خمسة سطور مثل `0 → 230 (0x00E6)`، `1 → 1500 (0x05DC)` تمثّل قيم السجلّات (مثل جهد ومعدّل دوران).

**English:** Host `192.168.1.50`, port `502`, unit `1`, function `Holding` (`3`), address `0`, quantity `5`. Expected: five rows like `0 → 230 (0x00E6)`, `1 → 1500 (0x05DC)` representing register values (e.g. a voltage and an RPM).

## ملاحظات وقيود · Notes & limitations
**بالعربي:** Modbus TCP بلا تشفير ولا مصادقة إطلاقًا — أي جهاز على الشبكة يمكنه القراءة والكتابة. لا تعرّض أجهزة Modbus على الإنترنت العام. الأداة تقرأ فقط (لا تكتب سجلّات ولا تغيّر حالة الجهاز)، وتدعم الدالتين `3` و `4` فقط (لا قراءة ملفّات coils/discrete inputs). الكمّية القصوى `125` سجلًّا لكل طلب. مهلة الاتصال `6` ثوانٍ. كل شيء يبقى على الجهاز عدا الطلب المُرسَل للهدف.

**English:** Modbus TCP has no encryption and no authentication whatsoever — any device on the network can read and write. Do not expose Modbus devices to the public internet. The tool is read-only (it does not write registers or change device state) and supports functions `3` and `4` only (no coils/discrete inputs). The maximum quantity is `125` registers per request. The connection timeout is `6` seconds. Everything stays on the device except the request sent to the target.
