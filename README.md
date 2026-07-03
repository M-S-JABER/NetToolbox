# NetToolbox 🧰

**English** | [العربية](#nettoolbox--بالعربية)

A modular network-tools app for **iPad**, built as a **Swift Playgrounds App project** (`.swiftpm`) — it opens and builds both in **Swift Playgrounds on iPad** and in **Xcode on macOS**. No Mac required for development.

- **Swift 6-style strict concurrency**, SwiftUI, SwiftData, async/await + actors
- **iOS 17+, iPad-only**, optimized for iPad screens (`NavigationSplitView` sidebar + adaptive tool grid)
- **No external dependencies** in Phase 1
- Bilingual UI (English + Arabic) with correct RTL — technical values (IP/MAC/hex/ports) always render LTR

## Using it — directly from the repo URL (recommended)

The repo root is a Swift package with a library product **`NetToolboxKit`** and semver version tags, so Swift Playgrounds can consume it straight from the URL:

1. In Swift Playgrounds, open (or create) an **App** playground.
2. Tap **⋯ → Add Package** (or *Package Dependencies*), paste
   `https://github.com/M-S-JABER/NetToolbox`
   pick the latest version (e.g. **1.0.0**) and **Add to App Playground**.
3. Replace your `MyApp.swift` body with:

```swift
import SwiftUI
import NetToolboxKit

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup { NetToolboxRootView() }
    }
}
```

That's it — press **Run**. `NetToolboxRootView(theme:)` also accepts a custom `Theme` to re-skin the whole app.

## Alternative: the bundled app playground

`NetToolbox.swiftpm` is a thin app (just the `@main` entry point) that depends on this repo's package. Copy that folder into *Playgrounds* via the Files app and run it; Swift Playgrounds resolves `NetToolboxKit` from GitHub on first open.

**On macOS:** open the repo folder as a package in Xcode 15+ (runs `swift test` too), or open `NetToolbox.swiftpm` and run on an iPad simulator.

## Shipped tools (all working, no external dependencies)

**Phase 1 — calculators & reference**

| Tool | Highlights |
|---|---|
| **Subnet Calculator** | Full IPv4 (network, broadcast, usable range, host counts, wildcard, binary, class, private/public, `/31` RFC 3021, `/32`), IPv6 basics (expand/compress, network prefix, address type). Pure `SubnetEngine` with unit tests. |
| **MAC / OUI Lookup** | Accepts any format (`:`/`-`/Cisco dots/raw hex), normalizes, offline vendor lookup from bundled `oui.json` (~300 well-known OUIs), multicast + locally-administered bit analysis. |
| **Common Ports** | Searchable, filterable reference of well-known TCP/UDP ports. |

**Phase 2 — diagnostics**

| Tool | Highlights |
|---|---|
| **Public IP & ISP** | Public IP, country, city, ISP, org, ASN via `ipwho.is` (HTTPS), plus local interface addresses via `getifaddrs`. |
| **Ping (TCP)** | Repeated TCP-handshake latency to a host/port with min/avg/max + packet loss. iOS blocks raw ICMP, so this is the reliable native equivalent. |
| **Port Scanner** | Concurrent TCP port probing (`NWConnection`) with common/web/all presets and service names. |
| **DNS Lookup** | Custom UDP resolver (pure `DNSMessage` codec) for A, AAAA, CNAME, MX, NS, TXT, SOA, PTR against any server. |
| **WHOIS** | TCP port-43 client with per-TLD server selection. |
| **SSL/TLS Checker** | TLS handshake inspection: subject, issuer, validity window, days-to-expiry, chain length, system trust. |
| **Wake-on-LAN** | Broadcast magic packet via a `SO_BROADCAST` UDP socket. |
| **Engine Self-Tests** | Runs the full engine + codec test suite **on-device** — same vectors as the XCTest target, since XCTest can't run in Swift Playgrounds. |

**Phase 3 — professional**

| Tool | Highlights |
|---|---|
| **Telnet** | Interactive plaintext TCP terminal with RFC 854 option negotiation (pure `TelnetProtocol`). |
| **MikroTik API** | RouterOS API client (port 8728) — variable-length word framing, plain login (6.43+), send any command and read `!re`/`!done`/`!trap` replies. |
| **SNMP GET** | SNMP v2c GET over UDP with a hand-rolled BER codec (`SNMPMessage`) and common `sysX` OID presets. |

**Native utilities**

| Tool | Highlights |
|---|---|
| **Traceroute** | ICMP echo with increasing TTL over an unprivileged `SOCK_DGRAM`/`IPPROTO_ICMP` socket (Apple's SimplePing socket type) — shows each hop and RTT, no entitlement needed. |
| **IP Info Lookup** | Geo/ISP/ASN for any IP or hostname (not just the device's own) via ipwho.is. |
| **HTTP Headers** | Fetches a URL and lists status code, final URL and all response headers. |
| **NTP Time** | SNTP query (pure `NTP` codec) reporting server time and this device's clock offset. |
| **Text Converter** | Offline Base64 / Hex / URL encode & decode (pure `TextConverter`). |
| **Wi-Fi QR Code** | Generates a `WIFI:` QR (pure payload builder + CoreImage) to share network access. |

## Architecture

The core idea is a **Tool Registry**: the home screen (sidebar + grid) is generated from `ToolRegistry.all`. Adding a tool = one type conforming to `NetworkTool` + one registration line — the main screen is never touched.

```
├── Package.swift                     # Root library package: NetToolboxKit (iOS 17)
├── Sources/NetToolboxKit/
│   ├── NetToolboxRootView.swift      # Public entry view (the only public surface + Theme)
│   ├── App/                          # Registry-driven root screen, routes
│   ├── Core/
│   │   ├── DesignSystem/             # Theme protocol + tokens + shared components
│   │   ├── ToolKit/                  # NetworkTool protocol + ToolRegistry
│   │   ├── Networking/               # HTTPDataClient protocol + URLSession client
│   │   ├── Persistence/Models/       # SwiftData: HistoryEntry, SavedHost, Favorite
│   │   └── Extensions/               # incl. L10n helpers (package-bundle lookups)
│   ├── Features/                     # One folder per tool: Tool + View + ViewModel (+ Engine)
│   └── Resources/                    # en/ar .lproj string tables, oui.json
├── Tests/NetToolboxKitTests/         # XCTest mirror of the on-device suite
└── NetToolbox.swiftpm/               # Thin app playground (@main only, depends on the kit)
```

Rules enforced across the codebase:

- Every service sits behind a **protocol** (`OUIProviding`, `PublicIPProviding`, `LocalIPProviding`, `HTTPDataClient`) → swappable and mockable.
- **No business logic in Views** — light MVVM: `View` + `@Observable` ViewModel + Service/Engine.
- No force unwraps, no `try!`; typed errors with bilingual `LocalizedError` descriptions.
- **Theming**: views read colors only via `@Environment(\.theme)` (semantic tokens: background, surface, accent, success/warning/danger, mono…). Swap the whole look with one line in `NetToolboxApp`. Dark-first, light fully supported, Dynamic Type friendly.

## Tests

- On iPad: open **Diagnostics → Engine Self-Tests** inside the app and tap *Run tests* (covers `/24`, `/30`, `/31`, `/32`, dotted & non-contiguous masks, invalid input, IPv6 parsing/types, MAC normalization, OUI lookup).
- On macOS: open the repo as a package and run `swift test` — `Tests/NetToolboxKitTests/SubnetEngineTests.swift` contains the same vectors as XCTest.

## Notes & known limitations on iOS (why some tools aren't here)

- **Wi-Fi analyzer** (scanning nearby networks/channels/signal): **not possible on iOS** — no public API.
- **Packet capture**: not possible without special VPN/NE entitlements.
- **Current Wi-Fi SSID/BSSID**: requires an entitlement + location permission — deferred.
- **Ping** is a TCP-handshake latency probe, not ICMP echo — iOS has no public raw-socket API.
- **LAN scanning** (Bonjour + ping sweep) and reading the **current Wi-Fi SSID** need the *Local Network* / location entitlements, which a `.swiftpm` playground cannot declare reliably — deferred.
- The bundled OUI database is **abridged** (~300 famous vendors). Replace `Resources/oui.json` with a fuller IEEE-derived map anytime — same `{"XXXXXX": "Vendor"}` format.

## Remaining roadmap

- **Traceroute** — needs per-hop TTL control and reading ICMP time-exceeded replies via raw sockets, which iOS does not permit. A UDP/TCP-TTL best-effort variant is possible later.
- **LAN scanner** (ping sweep + Bonjour `NWBrowser`) — pending a host app that declares `NSLocalNetworkUsageDescription` + `NSBonjourServices`.
- **SSH client** — a working SSH needs a crypto/transport library (SwiftNIO SSH / Citadel). Adding it as a package dependency is a dead end for the primary target: **Swift Playgrounds on iPad cannot evaluate a manifest with remote SPM dependencies** ("Could not decode ContextModel parameter"), which breaks loading of the whole package. A future option is a from-scratch SSH transport built on the system **CryptoKit** (no dependency) — large but Playgrounds-safe.

Each tool follows the same pattern: `Features/<Name>/` with a type conforming to `NetworkTool`, registered in `ToolRegistry.all` — the home screen updates itself.

## License

MIT — see [LICENSE](LICENSE).

---

# NetToolbox 🧰 — بالعربية

تطبيق أدوات شبكات **معياري (modular)** للآيباد، مبني كمشروع **Swift Playgrounds App** بصيغة `.swiftpm` — يفتح ويُبنى في **Swift Playgrounds على الآيباد** وفي **Xcode على الماك**. لا حاجة لجهاز Mac للتطوير.

- Swift 6 (تدقيق تزامن صارم)، SwiftUI، SwiftData، async/await
- **iOS 17+، مخصص للآيباد فقط** ومُحسّن لشاشاته (شريط جانبي `NavigationSplitView` + شبكة أدوات متكيفة)
- بدون أي مكتبات خارجية في المرحلة الأولى
- واجهة ثنائية اللغة (عربي/إنجليزي) مع دعم RTL صحيح — القيم التقنية (IP/MAC/hex) تبقى دائماً باتجاه LTR

## الاستخدام — مباشرة من رابط الريبو (الطريقة الموصى بها)

جذر المستودع حزمة Swift بمنتج مكتبة **`NetToolboxKit`** مع وسوم إصدارات، لذا يمكن لـ Swift Playgrounds استهلاكها من الرابط مباشرة:

1. في Swift Playgrounds افتح (أو أنشئ) مشروع **App**.
2. اضغط **⋯ ← Add Package**، والصق الرابط
   `https://github.com/M-S-JABER/NetToolbox`
   واختر أحدث إصدار (مثل **1.0.0**) ثم **Add to App Playground**.
3. استبدل محتوى `MyApp.swift` بـ:

```swift
import SwiftUI
import NetToolboxKit

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup { NetToolboxRootView() }
    }
}
```

اضغط **تشغيل** وينتهي الأمر. كما تقبل `NetToolboxRootView(theme:)` ثيماً مخصصاً لتغيير مظهر التطبيق كاملاً.

## بديل: مشروع التطبيق المرفق

مجلد `NetToolbox.swiftpm` تطبيق رفيع (نقطة دخول `@main` فقط) يعتمد على حزمة هذا الريبو. انسخه إلى *Playgrounds* عبر تطبيق الملفات وشغّله — وسيجلب Swift Playgrounds مكتبة `NetToolboxKit` من GitHub عند أول فتح.

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

## الأدوات المُنجَزة (كلها تعمل بدون مكتبات خارجية)

- **المرحلة 1 — حسابات ومراجع:** حاسبة الشبكات الفرعية، فحص MAC/OUI، مرجع المنافذ.
- **المرحلة 2 — تشخيص:** العنوان العام والمزوّد، Ping (عبر TCP)، ماسح المنافذ، استعلام DNS، WHOIS، فاحص SSL/TLS، Wake-on-LAN، والاختبارات الذاتية على الجهاز.
- **المرحلة 3 — احترافي:** Telnet، عميل MikroTik API (RouterOS)، واستعلام SNMP v2c.

## ما تبقّى في خارطة الطريق

- **Traceroute:** يتطلب التحكم في TTL لكل قفزة وقراءة ردود ICMP، وهو غير متاح على iOS عبر واجهات عامة.
- **ماسح الشبكة المحلية** (ping sweep + Bonjour) وقراءة **SSID الحالي:** يحتاجان إذن *Local Network* الذي لا يمكن لمشروع `.swiftpm` الإعلان عنه بموثوقية — مؤجّلان.
- **عميل SSH:** يحتاج فعلاً مكتبة تشفير خارجية موثوقة (SwiftNIO SSH / Citadel)، وهذا يتعارض مع قيد "بدون مكتبات خارجية + قابل للبناء في Playgrounds"، لذا أُبقي خارجاً حتى تُقرَّ إضافة تبعية خارجية. كل ما عداه في المرحلتين 2 و3 مُنجَز هنا بدون أي تبعيات.

## الرخصة

MIT — راجع ملف [LICENSE](LICENSE).
