# NetToolbox — Status & Roadmap / الحالة وخارطة الطريق

> Living document. Read this first next session. / وثيقة حيّة — اقرأها أولاً في الجلسة القادمة.

Repo: `M-S-JABER/NetToolbox` · Branch: `claude/nettoolbox-ios-app-maqgmi`
Consumed as a Swift package (`NetToolboxKit`) added by URL in Swift Playgrounds.
Latest working tag: **1.43.0** · Tools: **65** · Localization: **en/ar at parity (980 keys)**

---

## 1) How it's built / كيف بُني

- Root is a **Swift package** with library `NetToolboxKit` (iOS 17). The app uses `NetToolboxRootView()`.
- **Zero external dependencies** — mandatory: Swift Playgrounds on iPad **cannot evaluate a `Package.swift` with remote dependencies** (fails with `Could not decode ContextModel`, breaking the whole package). Everything is native (Network.framework / POSIX / CryptoKit-free / CoreImage / MapKit).
- **Tool Registry pattern**: add a tool = one type conforming to `NetworkTool` + one line in `ToolRegistry.all`. The home screen builds itself.
- **Architecture**: light MVVM — `View` + `@Observable` ViewModel + Service/Engine behind a protocol. Pure logic (codecs/engines) is separated and unit-tested.
- **Localization**: every UI string via `L10n`/`L10nString` pinned to `Bundle.module`; en + ar `.lproj` tables must stay at parity.
- **Releases**: tags are cut by the `Tag release` GitHub Action (Actions → Run workflow → version), because the sandbox can't push tags. Bump a new tag per change.
- **Tests**: pure engines covered twice — on-device `EngineTestSuite` (Diagnostics → Engine Self-Tests) and `Tests/NetToolboxKitTests` (`swift test` on macOS).

### Repo checks before every release / فحوص قبل كل إصدار
- Brace balance across all `.swift`.
- Localization coverage + en/ar parity (no missing keys, equal counts).
- No `try!` / `print(` / force-unwrap; unique tool IDs.

---

## 2) What's done / ما أُنجز (65 tools)

**Calculators (16):** Subnet Calculator · Subnet Membership (IP-in-CIDR + range converter) · VLSM Planner · MAC/OUI Lookup · Common Ports · Base Converter · Text Converter (Base64/Hex/URL) · Password Generator · QR Generator · Hash & JWT (MD5/SHA + JWT decode, CryptoKit) · Hash Identifier · EUI-64 / SLAAC · CIDR Aggregator · Timestamp Converter · Generators (UUID/MAC/hex) · JSON Formatter.

**Diagnostics (30):** Public IP · IP Info Lookup (+ MapKit location) · Host→IP · Speed Test (download/upload/ping/jitter + ISP/edge, Cloudflare, history sparkline) · HTTP Request · History · Backup & Restore (export/import all data as JSON) · Ping (real ICMP/ICMPv6, pro options) · World Ping (globalping.io, worldwide probes) · Traceroute (ICMP, per-hop timeout/retries/max-hops) · Port Scanner (custom range/list + live progress) · DNS Lookup · DNS-over-HTTPS · DNS Compare (4 public resolvers, agreement check) · Email Security (SPF/DMARC/DKIM) · Pwned Password (HIBP k-anonymity) · Cert Transparency (crt.sh) · WHOIS · RDAP (structured WHOIS) · Banner Grab · HTTP Timing (waterfall) · Uptime Check (batch) · nslookup · SSL/TLS Checker (SANs) · HTTP Headers · Email Validator (+MX) · RBL Blacklist · NTP · Engine Self-Tests · Guide.

**Local Network (9):** Network Overview · Wi-Fi Info (device IP + Shortcut buttons) · Saved Hosts · LAN Scanner (Bonjour) · IP Range Scanner (ICMP sweep) · Wake-on-LAN (saved addresses) · **IP Cameras** (native RTSP live view + ONVIF auto-setup + PTZ + grid + recording) · Wi-Fi QR · **WireGuard QR** (Curve25519 keygen + scannable tunnel config).

**Professional (8):** SSH (native SSH-2, curve25519 + AES-256-GCM, password **or ed25519 key** auth, single-command exec **+ interactive shell**, saved profiles) · SFTP (browse + download over the SSH transport) · Telnet (saved addresses) · FTP (passive LIST) · MikroTik RouterOS API (terminal transcript UI: quick-command chips, per-record key/value formatting, auto-scroll, share/clear) · SNMP (GET + Walk, configurable port) · WebSocket (URLSessionWebSocketTask; send/receive frames, live transcript) · MQTT (native 3.1.1 over TCP/TLS; connect/subscribe/publish QoS 0, live messages).

**BGP (2):** ASN Info · IP→BGP (origin AS / prefix, via the public RIPEstat API).

**Design/UX (persistent sidebar, 1.17.0):** the home is a `NavigationSplitView` — a `.sidebar` tool list that stays open beside the detail pane on iPad and collapses to a phone-style push on iPhone. Sidebar rows are deliberately plain: a hollow SF Symbol + the tool's short name only (no boxes, tiles, or subtitles). Selecting a tool fills the detail column; swipe a row to favorite. Earlier native-iOS work (1.16.0): the previous inset-grouped `List` (Settings-app idiom) with system search, Settings-style colored icon tiles, a Favorites section, swipe-to-favorite, and a live network-status row. All surfaces use the system grouped-background / label colors (`ColorTokens` → `systemGroupedBackground` etc.), so every screen matches iOS and follows the system Light/Dark automatically (no more forced dark). 6 accent themes still tint controls; global search keeps smart input detection; unified history + share.

---

## 3) Impossible on iOS — do NOT retry / مستحيل على iOS (لا تُعِد المحاولة)

| Feature | Why blocked |
|---|---|
| ~~**SSH**~~ | **SHIPPED in 1.15.0.** The trick: negotiate ONLY `aes256-gcm@openssh.com`, which maps directly onto CryptoKit's `AES.GCM`, plus `curve25519-sha256` KEX and ed25519/ecdsa/rsa host-key verification — all native, zero deps. Limits: password auth only, single-command exec (no interactive PTY shell), needs a server offering aes-gcm. See `Features/SSH/`. |
| **SFTP** | Now feasible as a follow-up — it's a subsystem channel over the SSH transport we now have. Not built yet. |
| **Wi-Fi RSSI / channel / band / Wi-Fi generation / link speed** | No public API on iOS for any app. |
| **SSID / BSSID inside the app** | Needs the *Access WiFi Information* entitlement + location; a `.swiftpm` can't declare entitlements. Workaround shipped: the **Shortcuts app** (Get Network Details) — Wi-Fi Info has Run/Create buttons for a shortcut named `NetToolbox WiFi`. |
| **Default gateway / router MAC / router vendor** | The routing & ARP tables live in `net/route.h` (`rt_msghdr`, `RTF_GATEWAY`, `RTF_LLINFO`, `RTAX_*`, `NET_RT_DUMP`/`NET_RT_FLAGS`, `PF_ROUTE`). Those symbols are **macOS-only** and are not in the iOS Darwin module — they fail to compile ("cannot find in scope"). No iOS API exposes the gateway. |
| **Nearby Wi-Fi scan / packet capture** | Not possible on iOS. |
| **LAN scan without permission** | Bonjour + ICMP sweep need the Local Network permission; degrade to empty without it. |

---

## 4) Shipped from the previous suggestion list (1.14.0)

Subnet Membership · WHOIS field parsing · Saved Hosts · HTTP Request builder · DNS-over-HTTPS · Ping sparkline · History JSON export/import · SSL SANs · Bonjour TXT. (Router vendor via ARP was attempted but removed — the routing/ARP tables are macOS-only; see section 3.) Next ideas below.

## 4b) Suggested next / اقتراحات الدفعة القادمة (feasible, native)

Ranked by value × low risk:

1. **Saved Hosts** — a store + manager, and a picker to reuse hosts in Ping/Traceroute/Port Scan/SSH-less tools. (Store like `FavoritesStore`.)
2. **Ping graph** — continuous ping with a simple latency sparkline over time.
3. **Subnet membership / IP-in-range** — "is 10.0.0.5 inside 10.0.0.0/24?" + CIDR↔range converter (extends `SubnetEngine`).
4. **mDNS/Bonjour details** — resolve a discovered service to host + port + TXT records (extends LAN Scanner).
5. **DNS-over-HTTPS (DoH)** — DNS via `https://cloudflare-dns.com/dns-query` as an alternative resolver.
6. **HTTP request builder** — method/headers/body, show response (like a mini Postman).
7. **Certificate details+** — full chain, SANs, signature algorithm (extend SSL Checker).
8. **Export/import settings & history** — a JSON file via ShareLink / file importer.
9. **MAC vendor from gateway** — read ARP table (sysctl) + OUI lookup to name the router vendor.
10. **Whois parsing** — extract registrar/created/expires into fields instead of raw text.

---

## 4c) IP Cameras — multi-phase / كاميرات IP (على مراحل)

Native, zero-dep camera stack (no VLCKit/ffmpeg — AVPlayer can't do RTSP).
- **Phase 1 — Live view (1.29.0, DONE):** `Features/Camera/*`. RTSP-over-TCP
  client (`RTSPClient`, interleaved RTP, Basic/Digest auth via CryptoKit MD5),
  `VideoDepacketizer` (H.264 RFC 6184 + H.265 RFC 7798 → access units),
  `SampleBufferBuilder` (CoreMedia format desc + `CMSampleBuffer`) rendered by
  `AVSampleBufferDisplayLayer`. `CameraStore` bank, `CameraSession` persists the
  stream across navigation, fullscreen. Tested on real hardware — expect
  per-vendor RTP quirks to iterate on.
- **Phase 2 — ONVIF (1.30.0, DONE):** `ONVIFClient` (SOAP 1.2 over URLSession,
  WS-UsernameToken PasswordDigest with camera-clock `Created`), `ONVIFParsers`
  (XMLParser delegates). `GetSystemDateAndTime`, `GetDeviceInformation`,
  `GetCapabilities` (Media/PTZ XAddr), `GetProfiles`, `GetStreamUri`
  (auto-fills RTSP path/port), `GetSnapshotUri`. Editor "Configure via ONVIF"
  with profile picker + device info; `SnapshotFetcher` (Basic/Digest JPEG);
  `CameraScanner` unicast /24 sweep of port 554 (multicast WS-Discovery needs an
  entitlement unavailable in Playgrounds). `Camera` gained optional
  `snapshotURI`/`ptzXAddr`/`profileToken` (optional = old cameras still decode).
- **Phase 3 — PTZ (1.31.0, DONE):** `ONVIFClient` PTZ ops (`ContinuousMove`,
  `Stop`, `GetPresets`, `GotoPreset`) with a per-request WS-Security `Created`
  aligned to the camera clock via `measureClockOffset()`. `CameraPTZ.swift`:
  `PTZController` + `PTZSection` control pad (press-and-hold pan/tilt/zoom via
  `PTZHoldButton`) + preset recall, shown under the live view when the camera
  reports a PTZ service.
- **Phase 4 — grid + recording (1.33.0, DONE):** `CameraGrid` plays every saved
  camera at once (one `CameraSession` per cell). `CameraRecorder` writes the
  live H.264/H.265 straight to an MP4 in Documents via `AVAssetWriter`
  passthrough (starts on the first keyframe; delta frames flagged `NotSync` in
  `SampleBufferBuilder`), then a `ShareLink` sheet exports it. IP-camera stack
  complete. Recording/grid still want real-hardware verification.

## 5) Release checklist / قائمة الإصدار

1. Add feature files under `Sources/NetToolboxKit/Features/<Name>/`.
2. Register in `ToolRegistry.all`.
3. Add en + ar keys (keep parity).
4. Add self-tests for any pure logic (both `EngineTestSuite` and XCTest).
5. Run the repo checks (braces / localization parity / no forbidden patterns / unique IDs).
6. Commit (Conventional Commits), push the branch.
7. Actions → **Tag release** → run with the next version → verify the tag exists.
8. Tell the user the tag + what to test; ask for a screenshot on any build error.
