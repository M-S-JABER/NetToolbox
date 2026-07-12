# Engine Self-Test · الاختبار الذاتي للمحرّك

> **Category / التصنيف:** Diagnostics / التشخيص  
> **Tool ID:** `self-test`

---

## نظرة عامة · Overview
**بالعربي:** أداة الاختبار الذاتي تشغّل مجموعة اختبارات المحرّك المدمجة (`EngineTestSuite`) على الجهاز مباشرةً، وتتحقق من صحة منطق كل المحرّكات الحسابية والبروتوكولية داخل التطبيق ضد متجهات اختبار معروفة. صُمّمت لتمكين التحقق من الهندسة حتى داخل Swift Playgrounds على iPad حيث لا يتوفّر XCTest. كل الاختبارات محلية ولا تتصل بالشبكة.
**English:** The Engine Self-Test runs the built-in engine test suite (`EngineTestSuite`) directly on the device, verifying the correctness of all of the app's computational and protocol engines against known test vectors. It is designed so engine logic can be validated even inside Swift Playgrounds on iPad, where XCTest is unavailable. All tests are local and make no network calls.

## كيف تعمل · How it works
**بالعربي:** عند الضغط على «تشغيل» يستدعي العرض `EngineTestSuite.runAll()`، الذي ينفّذ عشرات حالات الاختبار المستقلة، كل حالة تُعيد `nil` عند النجاح أو رسالة عند الفشل. تُقارن الحالات النتائج الفعلية بالمتوقّعة عبر مساعدات مثل `expect(_, equals:)` و`expectThrows`. تغطّي الحالات محرّكات عديدة، منها: حساب الشبكات الفرعية IPv4/IPv6 (`SubnetEngine`)، عناوين MAC وقاعدة OUI، تشفير/فك DNS (`DNSMessage`)، SNMP وSNMPv3 (اشتقاق مفاتيح USM بمتجهات RFC 3414)، NTP، ICMP، Wake-on-LAN، Telnet، MikroTik، iperf3، تحليل X.509، تحويلات النصوص والأرقام و Base64، دوال التجزئة (MD5/SHA1/SHA256 بمتجهات معروفة)، JWT، تصنيف TLS (`TLSAudit`)، مستويات انتهاء الشهادات، بصمة الخدمات، تحليل WHOIS، VLSM، تجميع CIDR، EUI-64/SLAAC، WireGuard (اشتقاق مفاتيح Curve25519)، وغيرها.
**English:** When "Run" is pressed, the view calls `EngineTestSuite.runAll()`, which executes dozens of independent test cases; each returns `nil` on pass or a message on failure. Cases compare actual results to expected via helpers like `expect(_, equals:)` and `expectThrows`. The cases cover many engines, including: IPv4/IPv6 subnet math (`SubnetEngine`), MAC addresses and the OUI database, DNS message encode/decode (`DNSMessage`), SNMP and SNMPv3 (USM key derivation with RFC 3414 vectors), NTP, ICMP, Wake-on-LAN, Telnet, MikroTik, iperf3, X.509 parsing, text/number/Base64 conversions, hash functions (MD5/SHA1/SHA256 with known-answer vectors), JWT, TLS grading (`TLSAudit`), certificate-expiry levels, service fingerprinting, WHOIS parsing, VLSM, CIDR aggregation, EUI-64/SLAAC, WireGuard (Curve25519 key derivation), and more.

## المدخلات · Inputs
**بالعربي:** لا مدخلات. زر **تشغيل** (Run) واحد يبدأ كامل المجموعة. / No inputs. A single **Run** button starts the whole suite.
**English:** No inputs. A single **Run** button starts the whole suite.

## المخرجات · Outputs
**بالعربي:** ملخّص بصيغة `اجتاز / الإجمالي` (مثل `62 / 62`) مع بشارة خضراء عند نجاح الكل أو حمراء عند وجود إخفاقات. ثم قائمة بكل حالة مع علامة نجاح/فشل، وتظهر رسالة تشخيصية تحت أي حالة فاشلة توضّح القيمة المتوقّعة مقابل الفعلية.
**English:** A summary in the form `passed / total` (e.g. `62 / 62`) with a green badge if all pass or red if there are failures. Then a list of every case with a pass/fail icon; any failing case shows a diagnostic message below it giving the expected versus actual value.

## مثال تشغيل · Worked example
**بالعربي:** الضغط على «تشغيل» يعرض `62 / 62` وبشارة `All passed`. لو فشلت حالة «TLS grade heuristics» لظهرت رسالة مثل `modern EC: expected A+, got A`.
**English:** Pressing "Run" shows `62 / 62` and an `All passed` badge. If, say, the "TLS grade heuristics" case failed, it would show a message like `modern EC: expected A+, got A`.

## ملاحظات وقيود · Notes & limitations
**بالعربي:** هذه الأداة للمطوّرين للتحقق من منطق المحرّكات فقط، ولا تختبر الاتصال الشبكي الفعلي أو واجهة المستخدم. تعمل بالكامل دون إنترنت أو أذونات. تعكس المجموعة متجهات الاختبار في `Tests/NetToolboxKitTests`.
**English:** This is a developer tool for verifying engine logic only; it does not test real network connectivity or the UI. It runs entirely offline with no permissions. The suite mirrors the test vectors in `Tests/NetToolboxKitTests`.
