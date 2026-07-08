# App Store submission notes / ملاحظات النشر على App Store

Ready-to-paste metadata for App Store Connect. The app is local-first: it
does no tracking and collects no data off-device (see `PrivacyInfo.xcprivacy`).

---

## Identity

- **Name:** NetToolbox
- **Bundle ID:** `com.aswaralmudun.nettoolbox`
- **Version:** 1.4.0 (matches the app playground `displayVersion` and Settings → About)
- **Category:** Utilities (secondary: Developer Tools)
- **Supported devices:** iPad + iPhone, iOS 17+
- **Localizations:** English, Arabic (RTL)

## Privacy

- **Tracking:** none. `NSPrivacyTracking = false`, no tracking domains.
- **Data collected:** none off-device. Saved hosts, SSH profiles, cameras and
  history stay on the device (`UserDefaults` + Keychain). Backups are
  user-initiated files, optionally passphrase-encrypted.
- **Privacy manifest:** `Sources/NetToolboxKit/Resources/PrivacyInfo.xcprivacy`
  declares the `UserDefaults` API reason `CA92.1`.
- **Nutrition label:** "Data Not Collected."

## Required Info.plist usage strings

Declared in `NetToolbox.swiftpm/Package.swift` via `.iOSApplication(capabilities:)`:

| Key | Feature |
| --- | --- |
| `NSFaceIDUsageDescription` | App lock (Face ID / Touch ID / passcode) |
| `NSCameraUsageDescription` | QR-code scanner (Wi-Fi, WireGuard) |
| `NSPhotoLibraryAddUsageDescription` | Save camera snapshots to Photos |
| `NSLocalNetworkUsageDescription` + `NSBonjourServices` | Bonjour browser, LAN scan, IP cameras |

## Description (English)

NetToolbox is a professional network toolkit for iPad and iPhone — 76 native
tools in one app, with zero tracking and no accounts.

Calculators: subnet & VLSM planning, CIDR aggregation, MAC/OUI lookup, base and
text converters, hashing and JWT, regex, and more. Diagnostics: ping, world
ping, traceroute, DNS/DoH, WHOIS/RDAP, TLS inspection, HTTP timing, port and IP
scanning, uptime and certificate monitors. Professional: native SSH shell,
SFTP, Telnet, FTP, MikroTik API, SNMP, WebSocket, MQTT, Redis, Modbus and more.
Local network: Bonjour discovery, LAN scanner, and full IP-camera control —
ONVIF + RTSP live view, PTZ, multi-camera grid and recording.

Privacy-first: everything runs on device. Secrets are stored in the Keychain,
backups can be encrypted with a passphrase, and an optional Face ID / passcode
lock keeps your saved connections private.

## Description (Arabic) / الوصف بالعربية

NetToolbox حقيبة أدوات شبكات احترافية للآيباد والآيفون — 76 أداة أصلية في تطبيق
واحد، دون أي تتبّع ودون حسابات.

حاسبات الشبكات وتخطيط VLSM، أدوات التشخيص (ping، traceroute، DNS/DoH،
WHOIS، فحص TLS، مسح المنافذ)، وأدوات احترافية (SSH، SFTP، SNMP، MQTT،
MikroTik)، واكتشاف الأجهزة على الشبكة المحلية، والتحكم الكامل بكاميرات IP عبر
ONVIF وRTSP مع بث حيّ وتحريك PTZ وتسجيل.

الخصوصية أولاً: كل شيء يعمل على الجهاز. تُحفظ الأسرار في Keychain، ويمكن تشفير
النسخ الاحتياطية بكلمة مرور، وقفل اختياري بـ Face ID أو رمز الدخول يحمي اتصالاتك
المحفوظة.

## Keywords

network, subnet, ping, traceroute, dns, ssh, snmp, port scanner, ip camera,
onvif, rtsp, wireguard, mqtt, modbus, whois, tls, mac lookup

## What's New (1.4.0)

- Secrets now stored in the Keychain instead of clear text.
- Optional passphrase-encrypted backups (AES-256-GCM).
- Optional Face ID / Touch ID / passcode app lock.
- Haptics and refined plural/localization handling.
- Privacy manifest and continuous-integration build/test pipeline.
