# App Store submission notes / ملاحظات النشر على App Store

Ready-to-paste metadata for App Store Connect. The app is local-first: it
does no tracking and collects no data off-device (see `PrivacyInfo.xcprivacy`).

---

## Identity

- **Name:** NetToolbox
- **Bundle ID:** `com.aswaralmudun.nettoolbox`
- **Version:** 2.3.0 (matches the app playground `displayVersion` and Settings → About)
- **Category:** Utilities (secondary: Developer Tools)
- **Supported devices:** iPad + iPhone, iOS 26.0+
- **Localizations:** English, Arabic (RTL)
- **Tools:** 81 in the tool list across 7 categories (Calculators, Diagnostics,
  DNS & Domains, Security, Local Network, Professional, BGP) + History, Backup
  and Engine Self-Tests inside Settings.

## Privacy

- **Tracking:** none. `NSPrivacyTracking = false`, no tracking domains.
- **Data collected:** none off-device. Saved hosts, SSH profiles, cameras and
  history stay on the device (`UserDefaults` + Keychain). Backups are
  user-initiated files, optionally passphrase-encrypted.
- **Privacy manifest:** shipped in two places — the app target
  (`NetToolbox.swiftpm/PrivacyInfo.xcprivacy`) and the package
  (`Sources/NetToolboxKit/Resources/PrivacyInfo.xcprivacy`). Both declare the
  `UserDefaults` API reason `CA92.1` and no tracking / no collected data.
- **Nutrition label:** "Data Not Collected."

## Required Info.plist usage strings

Declared in `NetToolbox.swiftpm/Package.swift` via `.iOSApplication(capabilities:)`:

| Key | Feature |
| --- | --- |
| `NSFaceIDUsageDescription` | App lock (Face ID / Touch ID / passcode) |
| `NSCameraUsageDescription` | QR-code scanner (Wi-Fi, WireGuard) |
| `NSPhotoLibraryAddUsageDescription` | Save camera snapshots to Photos |
| `NSLocalNetworkUsageDescription` + `NSBonjourServices` | Bonjour browser, LAN scan, IP cameras |

These are the **only** permissions the app requests, and each is prompted
lazily the first time its feature is used — none are asked for at launch.

## Capabilities / entitlements to enable

| Capability | Needed by | Where to enable |
| --- | --- | --- |
| Keychain (default) | Storing SSH/camera secrets | Automatic — no entitlement needed for the app's own keychain items |
| iCloud → **Key-value storage** | The optional "Sync settings via iCloud" toggle | Xcode → Signing & Capabilities → **+ iCloud** → tick *Key-value storage*. (Swift Playgrounds can't add this; the toggle simply no-ops until it's enabled.) |
| Face ID | App lock | Covered by `NSFaceIDUsageDescription` above — no separate entitlement |

Notes:
- No push, no background modes, no HealthKit/location — keep the entitlements
  list minimal so review is fast.
- App Transport Security: the app talks to user-supplied hosts (SSH, RTSP,
  plain HTTP tools by design). If a specific tool needs cleartext to a host the
  user typed, that is expected; document it in the review notes rather than
  disabling ATS globally.

## App icon

- **Wired in:** `NetToolbox.swiftpm/Package.swift` uses `appIcon: .asset("AppIcon")`,
  backed by `NetToolbox.swiftpm/Assets.xcassets/AppIcon.appiconset/` (1024×1024
  PNG). The `.earth` placeholder is no longer used.
- Design source: `NetToolbox.swiftpm/AppIcon.svg` (1024×1024, no text, teal
  network hub-and-spoke motif). Re-export to `AppIcon.appiconset/AppIcon.png`
  (no alpha) if you tweak the SVG.

## How to submit

**Prerequisites:** an Apple Developer Program membership ($99/yr) and an app
record in App Store Connect (`appstoreconnect.apple.com` → Apps → +).

### Path A — straight from Swift Playgrounds on iPad
1. Open the app project → tap the title menu → **App Store Connect** →
   **Publish App**. Playgrounds builds, signs (with your developer account) and
   uploads the build for you.
2. In App Store Connect, the build appears under the app's **TestFlight** /
   **App Store** tab after processing (a few minutes).

### Path B — Xcode on a Mac (needed for the iCloud entitlement)
1. Open the `.swiftpm` in Xcode (File → Open) or create an App target that
   imports `NetToolboxKit`.
2. Signing & Capabilities: pick your team; add **iCloud → Key-value storage**
   if you want the sync toggle to work.
3. Set version 2.3.0, build number, and confirm the 1024 icon in `Assets.xcassets`.
4. Product → **Archive** → **Distribute App** → **App Store Connect** → Upload.

### Then, in App Store Connect (both paths)
1. **App information:** name, subtitle, category (Utilities), privacy policy URL.
2. **Privacy → Data collection:** answer **"Data Not Collected"** (matches
   `PrivacyInfo.xcprivacy`).
3. **Version metadata:** paste the description/keywords/"What's New" from this
   file; add screenshots (6.7" iPhone + 12.9" iPad required).
4. **Build:** select the uploaded build.
5. **Age rating**, **export compliance** (uses only standard OS encryption →
   usually exempt; answer the encryption question accordingly).
6. **Submit for Review.**

## Description (English)

NetToolbox is a professional network toolkit for iPad and iPhone — 80+ native
tools in one app, with zero tracking and no accounts.

Calculators: subnet & VLSM planning, CIDR aggregation, MAC/OUI lookup, base and
text converters, hashing and JWT, regex, and more. Diagnostics: ping, world
ping, traceroute, MTR, HTTP timing, port scanning, speed test. DNS & Domains:
DNS lookup, DoH, multi-resolver compare, DNS health, WHOIS and RDAP. Security:
TLS/SSL inspection, certificate expiry and transparency, email authenticity
(SPF/DKIM/DMARC), blocklist and breach checks. Professional: native SSH shell,
SFTP, Telnet, FTP, MikroTik API, SNMP, WebSocket, MQTT, Redis, Modbus and more.
Local network: Bonjour discovery, LAN scanner, and full IP-camera control —
ONVIF + RTSP live view, PTZ, multi-camera grid and recording.

Every tool has a built-in "?" explanation in English and Arabic. Privacy-first:
everything runs on device. Secrets are stored in the Keychain, backups can be
encrypted with a passphrase, and an optional Face ID / passcode lock keeps your
saved connections private.

## Description (Arabic) / الوصف بالعربية

NetToolbox حقيبة أدوات شبكات احترافية للآيباد والآيفون — أكثر من 80 أداة أصلية في
تطبيق واحد، دون أي تتبّع ودون حسابات.

حاسبات الشبكات وتخطيط VLSM، أدوات التشخيص (ping، traceroute، MTR، توقيت HTTP،
مسح المنافذ، اختبار السرعة)، وفئة DNS والنطاقات (استعلام DNS، DoH، مقارنة
المُحلّلات، WHOIS وRDAP)، وفئة الأمان (فحص TLS، انتهاء وشفافية الشهادات، أمان
البريد، القوائم السوداء والتسريبات)، وأدوات احترافية (SSH، SFTP، SNMP، MQTT،
MikroTik)، واكتشاف الأجهزة على الشبكة المحلية، والتحكم الكامل بكاميرات IP عبر
ONVIF وRTSP مع بث حيّ وتحريك PTZ وتسجيل.

لكل أداة شرح مدمج بزر «؟» بالعربية والإنجليزية. الخصوصية أولاً: كل شيء يعمل على
الجهاز. تُحفظ الأسرار في Keychain، ويمكن تشفير النسخ الاحتياطية بكلمة مرور، وقفل
اختياري بـ Face ID أو رمز الدخول يحمي اتصالاتك المحفوظة.

## Keywords

network, subnet, ping, traceroute, dns, ssh, snmp, port scanner, ip camera,
onvif, rtsp, wireguard, mqtt, modbus, whois, tls, mac lookup

## What's New (2.3.0)

- New focused categories: DNS & Domains and Security, split out of Diagnostics.
- Every tool now has a built-in bilingual "?" explanation (Arabic + English).
- Collapsible category groups in the sidebar for a shorter, scannable list.
- History, Backup and Engine Self-Tests moved into Settings.
- Real app icon, and stability hardening across the protocol clients.
- Built with Swift 6 / iOS 26; 80+ tools, still zero third-party dependencies.

### Earlier (1.4.0)

- Secrets stored in the Keychain; optional passphrase-encrypted backups
  (AES-256-GCM); Face ID / passcode app lock; privacy manifest and CI pipeline.
