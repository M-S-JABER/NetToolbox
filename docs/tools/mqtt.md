# MQTT Client · عميل MQTT

> **Category / التصنيف:** Professional / احترافي  
> **Tool ID:** `mqtt`

---

## نظرة عامة · Overview
**بالعربي:** عميل MQTT أصلي يتصل بوسيط (broker)، يشترك في المواضيع (topics)، وينشر الرسائل، ويعرض الرسائل الواردة حيّا. مفيد لاختبار أجهزة إنترنت الأشياء (IoT) ووسطاء MQTT ومسارات الرسائل. يدعم الإصدار MQTT 3.1.1 بجودة خدمة QoS 0، مبنيّ على إطار `Network` بدون مكتبات خارجية.

**English:** A native MQTT client that connects to a broker, subscribes to topics, publishes messages, and displays incoming messages live. Useful for testing IoT devices, MQTT brokers, and message routing. It supports MQTT 3.1.1 at QoS 0, built on the `Network` framework with no external libraries.

## كيف تعمل · How it works
**بالعربي:** الأداة تفتح اتصال TCP (أو TLS إن فُعّل) إلى الوسيط، المنفذ `1883` افتراضيًا للاتصال العادي (و`8883` هو المعتاد لـ MQTT عبر TLS). البروتوكول MQTT 3.1.1: تُرسَل حزمة `CONNECT` بمُعرّف البروتوكول `MQTT` والمستوى `4`، مع علم "الجلسة النظيفة"، وإدراج اسم المستخدم/كلمة المرور إن وُجدا، ومعرّف عميل، ومهلة إبقاء الاتصال `60` ثانية. عند استلام `CONNACK` برمز `0` يُعتبر الاتصال ناجحًا ويبدأ مؤقّت `PINGREQ` للحفاظ على الجلسة. الاشتراك عبر `SUBSCRIBE` (النوع `0x82`) بجودة QoS 0، والنشر عبر `PUBLISH` (النوع `0x30`). الحزم الواردة من نوع `PUBLISH` تُفكَّك لاستخراج الموضوع والحمولة. أطوال الحزم تُرمَّز بترميز الطول المتغيّر (varint) لـ MQTT.

**English:** The tool opens a TCP connection (or TLS if enabled) to the broker, port `1883` by default for plain connections (`8883` is conventional for MQTT over TLS). The protocol is MQTT 3.1.1: a `CONNECT` packet is sent with protocol name `MQTT` and level `4`, a clean-session flag, optional username/password, a client ID, and a `60`-second keep-alive. On receiving `CONNACK` with return code `0` the connection is considered established and a `PINGREQ` timer starts to keep the session alive. Subscribing uses `SUBSCRIBE` (type `0x82`) at QoS 0, and publishing uses `PUBLISH` (type `0x30`). Incoming `PUBLISH` packets are decoded to extract the topic and payload. Packet lengths use MQTT's variable-length (varint) encoding.

## المدخلات · Inputs
- **Host / المضيف:** عنوان الوسيط، الافتراضي `test.mosquitto.org` · the broker address, default `test.mosquitto.org`.
- **Port / المنفذ:** الافتراضي `1883` · Defaults to `1883`.
- **TLS / التشفير:** مفتاح لتفعيل الاتصال المشفّر · toggle to enable an encrypted connection.
- **Client ID / معرّف العميل:** اختياري؛ إن تُرك فارغًا يُولَّد تلقائيًا مثل `nettoolbox-a1b2c3` · optional; if empty a random one like `nettoolbox-a1b2c3` is generated.
- **Username / Password / اسم المستخدم وكلمة المرور:** اختيارية للوسطاء المؤمَّنة · optional for authenticated brokers.
- **Topic / الموضوع:** الموضوع للاشتراك أو النشر، الافتراضي `nettoolbox/test` · the topic to subscribe/publish to, default `nettoolbox/test`.
- **Publish text / نص النشر:** الحمولة المراد نشرها · the payload to publish.

## المخرجات · Outputs
**بالعربي:** سجلّ حيّ مُلوّن يظهر فيه: رسائل النظام (اتصال/اشتراك/قطع)، والإجراءات الصادرة مثل `SUB nettoolbox/test` و `PUB nettoolbox/test → hello`، والرسائل الواردة بصيغة `topic ▸ payload`، والأخطاء. تظهر أقسام الموضوع (اشتراك/نشر) فقط بعد نجاح الاتصال. يُحتفَظ بآخر 300 مُدخَلة.

**English:** A live color-coded log showing: system messages (connected/subscribed/disconnected), outgoing actions like `SUB nettoolbox/test` and `PUB nettoolbox/test → hello`, incoming messages as `topic ▸ payload`, and errors. The topic section (subscribe/publish) appears only after a successful connection. The last 300 entries are kept.

## مثال تشغيل · Worked example
**بالعربي:** المضيف `test.mosquitto.org`، المنفذ `1883`، بدون TLS. بعد الاتصال، اشترك في `nettoolbox/test`، ثم انشر `hello` على نفس الموضوع. المتوقّع: "متّصل"، ثم `SUB nettoolbox/test`، ثم `PUB nettoolbox/test → hello`، ثم رسالة واردة `nettoolbox/test ▸ hello` (لأنك مشترك في نفس الموضوع الذي نشرت عليه).

**English:** Host `test.mosquitto.org`, port `1883`, no TLS. After connecting, subscribe to `nettoolbox/test`, then publish `hello` to the same topic. Expected: "connected", then `SUB nettoolbox/test`, then `PUB nettoolbox/test → hello`, then an incoming message `nettoolbox/test ▸ hello` (because you are subscribed to the topic you published on).

## ملاحظات وقيود · Notes & limitations
**بالعربي:** العميل يدعم QoS 0 فقط (تسليم بلا تأكيد، قد تُفقَد الرسائل)، ولا يدعم الرسائل المحتجَزة (retained) أو رسالة الوصية (will) أو المواضيع المُقسّمة بأنماط متقدّمة عند النشر. بدون TLS تُرسَل بيانات الاعتماد والرسائل بوضوح — فعّل TLS للوسطاء العامة أو الحسّاسة. الحزم الأكبر من 1 ميغابايت تُرفَض. مهلة الإبقاء `60` ثانية مع `PINGREQ` تلقائي. بيانات الاعتماد تبقى على الجهاز.

**English:** The client supports QoS 0 only (fire-and-forget delivery, messages may be lost) and does not support retained messages, a will message, or advanced topic patterns on publish. Without TLS, credentials and messages are sent in the clear — enable TLS for public or sensitive brokers. Packets larger than 1 MB are refused. The keep-alive is `60` seconds with automatic `PINGREQ`. Credentials stay on the device.
