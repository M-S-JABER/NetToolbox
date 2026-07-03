# NetToolbox 🧰

**English** | [العربية](#nettoolbox--بالعربية)

A modular network-tools app for **iPad**, built as a **Swift Playgrounds App project** (`.swiftpm`) — it opens and builds both in **Swift Playgrounds on iPad** and in **Xcode on macOS**. No Mac required for development.

- **Swift 6-style strict concurrency**, SwiftUI, SwiftData, async/await + actors
- **iOS 17+, iPad-only**, optimized for iPad screens (`NavigationSplitView` sidebar + adaptive tool grid)
- **No external dependencies** in Phase 1
- Bilingual UI (English + Arabic) with correct RTL — technical values (IP/MAC/hex/ports) always render LTR

## Opening the project

**On iPad (Swift Playgrounds 4.5+):**
1. Get the repo onto the iPad — e.g. clone with the *Working Copy* app, or download the repo ZIP.
2. Copy the `NetToolbox.swiftpm` folder into *On My iPad → Playgrounds* (or open it via Files).
3. Tap it in Swift Playgrounds and press **Run**.

**On macOS:** open `NetToolbox.swiftpm` with Xcode 15+ and run on an iPad simulator.

## Phase 1 tools (shipped & working)

| Tool | Highlights |
|---|---|
| **Subnet Calculator** | Full IPv4 (network, broadcast, usable range, host counts, wildcard, binary, class, private/public, `/31` RFC 3021, `/32`), IPv6 basics (expand/compress, network prefix, address type). Pure `SubnetEngine` with unit tests. |
| **MAC / OUI Lookup** | Accepts any format (`:`/`-`/Cisco dots/raw hex), normalizes, offline vendor lookup from bundled `oui.json` (~300 well-known OUIs), multicast + locally-administered bit analysis. |
| **Common Ports** | Searchable, filterable reference of well-known TCP/UDP ports. |
| **Public IP & ISP** | Public IP, country, city, ISP, org, ASN via `ipwho.is` (HTTPS), plus local interface addresses via `getifaddrs`. Offline handling + retry. |
| **Engine Self-Tests** | Runs the full engine test suite **on-device** — same vectors as `Tests/SubnetEngineTests.swift`, since XCTest can't run in Swift Playgrounds. |

## Architecture

The core idea is a **Tool Registry**: the home screen (sidebar + grid) is generated from `ToolRegistry.all`. Adding a tool = one type conforming to `NetworkTool` + one registration line — the main screen is never touched.

```
NetToolbox.swiftpm/
├── Package.swift                 # Swift Playgrounds App manifest (iOS 17, iPad-only)
├── App/                          # Entry point, registry-driven root, routes
├── Core/
│   ├── DesignSystem/             # Theme protocol + tokens + shared components
│   ├── ToolKit/                  # NetworkTool protocol + ToolRegistry
│   ├── Networking/               # HTTPDataClient protocol + URLSession client
│   ├── Persistence/Models/       # SwiftData: HistoryEntry, SavedHost, Favorite
│   └── Extensions/
├── Features/                     # One folder per tool: Tool + View + ViewModel (+ Engine)
├── Resources/                    # Localizable.xcstrings (en/ar), oui.json
└── Tests/                        # XCTest mirror of the on-device suite
```

Rules enforced across the codebase:

- Every service sits behind a **protocol** (`OUIProviding`, `PublicIPProviding`, `LocalIPProviding`, `HTTPDataClient`) → swappable and mockable.
- **No business logic in Views** — light MVVM: `View` + `@Observable` ViewModel + Service/Engine.
- No force unwraps, no `try!`; typed errors with bilingual `LocalizedError` descriptions.
- **Theming**: views read colors only via `@Environment(\.theme)` (semantic tokens: background, surface, accent, success/warning/danger, mono…). Swap the whole look with one line in `NetToolboxApp`. Dark-first, light fully supported, Dynamic Type friendly.

## Tests

- On iPad: open **Diagnostics → Engine Self-Tests** inside the app and tap *Run tests* (covers `/24`, `/30`, `/31`, `/32`, dotted & non-contiguous masks, invalid input, IPv6 parsing/types, MAC normalization, OUI lookup).
- In Xcode: `Tests/SubnetEngineTests.swift` contains the same vectors as XCTest (add a test target to run them; the file is excluded from the app target).

## Notes & known limitations on iOS (why some tools aren't here)

- **Wi-Fi analyzer** (scanning nearby networks/channels/signal): **not possible on iOS** — no public API.
- **Packet capture**: not possible without special VPN/NE entitlements.
- **Current Wi-Fi SSID/BSSID**: requires an entitlement + location permission — deferred.
- **LAN scanning**: requires the *Local Network* permission (iOS 14+) — planned for Phase 2.
- The bundled OUI database is **abridged** (~300 famous vendors). Replace `Resources/oui.json` with a fuller IEEE-derived map anytime — same `{"XXXXXX": "Vendor"}` format.

## Roadmap

**Phase 2 — Diagnostics** (needs the Local Network permission for LAN tools):
Ping (e.g. SwiftyPing), Traceroute, DNS Lookup, Port Scanner (Network.framework), Whois, SSL certificate checker, Wake-on-LAN, LAN scanner (ping sweep + Bonjour).

**Phase 3 — Professional**:
SSH client (Citadel) for MikroTik/Cisco, MikroTik API client with ready-made commands, SNMP, Telnet.

Each new tool follows the same pattern: `Features/<Name>/` with `<Name>Tool.swift` conforming to `NetworkTool`, registered in `ToolRegistry.all`.

## License

MIT — see [LICENSE](LICENSE).

---

# NetToolbox 🧰 — بالعربية

تطبيق أدوات شبكات **معياري (modular)** للآيباد، مبني كمشروع **Swift Playgrounds App** بصيغة `.swiftpm` — يفتح ويُبنى في **Swift Playgrounds على الآيباد** وفي **Xcode على الماك**. لا حاجة لجهاز Mac للتطوير.

- Swift 6 (تدقيق تزامن صارم)، SwiftUI، SwiftData، async/await
- **iOS 17+، مخصص للآيباد فقط** ومُحسّن لشاشاته (شريط جانبي `NavigationSplitView` + شبكة أدوات متكيفة)
- بدون أي مكتبات خارجية في المرحلة الأولى
- واجهة ثنائية اللغة (عربي/إنجليزي) مع دعم RTL صحيح — القيم التقنية (IP/MAC/hex) تبقى دائماً باتجاه LTR

## فتح المشروع على الآيباد

1. انقل المستودع إلى الآيباد — مثلاً عبر تطبيق *Working Copy* (استنساخ git) أو بتنزيل ZIP.
2. انسخ مجلد `NetToolbox.swiftpm` إلى *Playgrounds* في تطبيق الملفات.
3. افتحه في Swift Playgrounds واضغط **تشغيل**.

## أدوات المرحلة الأولى (جاهزة وشغّالة)

| الأداة | المزايا |
|---|---|
| **حاسبة الشبكات الفرعية** | IPv4 كامل (عنوان الشبكة، البث، نطاق المضيفات، الأعداد، Wildcard، الثنائي، الفئة، خاص/عام، ‎`/31`‎ و‎`/32`‎) + أساسيات IPv6. المنطق في `SubnetEngine` منفصل وقابل للاختبار. |
| **فحص MAC / المصنّع** | يقبل أي صيغة، يوحّدها، ويبحث عن الشركة المصنّعة أوفلاين في `oui.json` (~300 مورّد شهير) مع تحليل بتات Multicast والإدارة المحلية. |
| **المنافذ الشائعة** | مرجع قابل للبحث والتصفية لأشهر منافذ TCP/UDP. |
| **العنوان العام والمزوّد** | ‏IP العام، الدولة، المدينة، المزوّد، ASN عبر ‎`ipwho.is`‎ + العناوين المحلية للجهاز عبر `getifaddrs`، مع معالجة انقطاع الاتصال. |
| **اختبارات المحرك الذاتية** | تشغيل حزمة اختبارات المحرك **على الجهاز مباشرة** — لأن XCTest لا يعمل في Swift Playgrounds. |

## المعمارية باختصار

الفكرة الأساسية **سجل الأدوات (Tool Registry)**: الشاشة الرئيسية تُبنى تلقائياً من `ToolRegistry.all`. إضافة أداة جديدة = نوع واحد يطابق بروتوكول `NetworkTool` + سطر تسجيل واحد، دون لمس الشاشة الرئيسية.

- كل خدمة خلف **بروتوكول** (حقن تبعيات) → قابلة للاستبدال والمحاكاة في الاختبارات.
- لا منطق أعمال داخل الواجهات — نمط MVVM خفيف.
- لا `!` ولا `try!` — أخطاء مُعرّفة برسائل ثنائية اللغة.
- **الثيم**: الألوان دلالية فقط عبر `Environment` — تغيير كامل المظهر بسطر واحد. التصميم داكن أولاً مع دعم الوضع الفاتح.

## قيود iOS (لماذا لا توجد بعض الأدوات)

- **تحليل شبكات Wi-Fi المجاورة**: غير ممكن على iOS إطلاقاً (لا توجد واجهة عامة).
- **التقاط الحزم (Packet capture)**: غير ممكن.
- **قراءة SSID/BSSID الحالي**: يتطلب entitlement وإذن الموقع — مؤجل.
- **مسح الشبكة المحلية**: يتطلب إذن *Local Network* — مخطط للمرحلة الثانية.

## خارطة الطريق

- **المرحلة 2 — تشخيص:** Ping، Traceroute، DNS Lookup، Port Scanner، Whois، فاحص شهادات SSL، Wake-on-LAN، ماسح الشبكة المحلية (ping sweep + Bonjour).
- **المرحلة 3 — احترافي:** عميل SSH (مكتبة Citadel) لأجهزة MikroTik/Cisco، عميل MikroTik API بأوامر جاهزة، SNMP، Telnet.

## الرخصة

MIT — راجع ملف [LICENSE](LICENSE).
