# NetToolbox — Tool Reference

NetToolbox is a native iOS/iPadOS network toolkit with 84 tools spanning subnet math,
diagnostics, local-network discovery, and professional protocol clients. Everything runs
**100% on-device** — there are **zero third-party dependencies**; the app is built entirely
on Apple frameworks (Network.framework, CryptoKit, URLSession, Core Image, Foundation). The
only network traffic is the tool's own probes plus a handful of tools that clearly fetch
public data (public IP, speed test, WHOIS/RDAP, breach checks, global routing).

**A few notes before you start:**

- **Local Network permission.** The LAN Scanner, IP Range Scanner, SSDP/UPnP discovery, and
  IP Cameras need the iOS **Local Network** permission (and, for SSDP, the multicast
  entitlement). iOS prompts on first use; if nothing is found, enable it in
  *iOS Settings → NetToolbox → Local Network*. Without it these tools return empty rather
  than crash.
- **ICMP tools fall back to TCP.** Ping and the IP Range Scanner use ICMP echo where allowed;
  when a network filters ICMP, they automatically measure a **TCP handshake** instead so you
  still get a reachability/latency result. Traceroute likewise falls back to a TCP reachability
  probe when ICMP is blocked.
- **On-device by default.** Nothing is uploaded except the specific public API each tool names
  below. Saved hosts, SSH keys, and camera credentials stay in the device Keychain.

---

## Contents

**Calculators**
[Subnet Calculator](#subnet-calculator) · [Subnet Membership](#subnet-membership) · [VLSM Planner](#vlsm-planner) · [MAC / OUI Lookup](#mac--oui-lookup) · [Common Ports](#common-ports) · [Base Converter](#base-converter) · [Text Converter](#text-converter) · [Password Generator](#password-generator) · [QR Generator](#qr-generator) · [Hash & JWT](#hash--jwt) · [Hash Identifier](#hash-identifier) · [EUI-64 / SLAAC](#eui-64--slaac) · [CIDR Aggregator](#cidr-aggregator) · [Timestamp Converter](#timestamp-converter) · [Generators](#generators) · [JSON Formatter](#json-formatter) · [Regex Tester](#regex-tester) · [URL Parser](#url-parser) · [Data Calculator](#data-calculator)

**Diagnostics**
[Guide](#guide) · [Public IP & ISP](#public-ip--isp) · [IP Info Lookup](#ip-info-lookup) · [Host → IP](#host--ip) · [Speed Test](#speed-test) · [HTTP Request](#http-request) · [History](#history) · [Backup & Restore](#backup--restore) · [Ping (TCP)](#ping-tcp) · [World Ping](#world-ping) · [Traceroute](#traceroute) · [MTR Path Analysis](#mtr-path-analysis) · [Port Scanner](#port-scanner) · [DNS Lookup](#dns-lookup) · [DNS over HTTPS](#dns-over-https) · [DNS Compare](#dns-compare) · [DNS Stability](#dns-stability) · [DNS Health](#dns-health) · [Email Security](#email-security) · [Pwned Password](#pwned-password) · [Cert Transparency](#cert-transparency) · [WHOIS](#whois) · [RDAP Lookup](#rdap-lookup) · [Banner Grab](#banner-grab) · [Service Fingerprint](#service-fingerprint) · [HTTP Timing](#http-timing) · [Uptime Check](#uptime-check) · [Cert Expiry Monitor](#cert-expiry-monitor) · [nslookup](#nslookup) · [SSL/TLS Checker](#ssltls-checker) · [HTTP Headers](#http-headers) · [Email Validator](#email-validator) · [Blacklist Check](#blacklist-check) · [NTP Time](#ntp-time) · [Engine Self-Tests](#engine-self-tests)

**Local Network**
[Network Overview](#network-overview) · [Wi-Fi Info](#wi-fi-info) · [Saved Hosts](#saved-hosts) · [LAN Scanner](#lan-scanner) · [SSDP / UPnP Discovery](#ssdp--upnp-discovery) · [IP Range Scanner](#ip-range-scanner) · [Wake-on-LAN](#wake-on-lan) · [IP Cameras](#ip-cameras) · [Wi-Fi QR Code](#wi-fi-qr-code) · [WireGuard QR](#wireguard-qr)

**Professional**
[SSH](#ssh) · [SFTP](#sftp) · [Telnet](#telnet) · [FTP](#ftp) · [WebSocket](#websocket) · [MQTT Client](#mqtt-client) · [Redis](#redis) · [Modbus TCP](#modbus-tcp) · [SMTP Probe](#smtp-probe) · [Memcached](#memcached) · [CoAP Client](#coap-client) · [TFTP Client](#tftp-client) · [Syslog Receiver](#syslog-receiver) · [SNMP Trap Receiver](#snmp-trap-receiver) · [MikroTik API](#mikrotik-api) · [SNMP GET](#snmp-get) · [iperf3 Speed Test](#iperf3-speed-test)

**BGP**
[ASN Info](#asn-info) · [IP → BGP](#ip--bgp) · [RPKI Validator](#rpki-validator)

---

## Calculators

### Subnet Calculator
**Purpose**: Compute all the subnet facts for an IPv4 or IPv6 address and mask.
**How it works**: Pure on-device math — parses the address and prefix, then derives network,
broadcast, host range, masks, and binary/expanded forms locally. No network access.
**Example**: `192.168.1.10/24` → network `192.168.1.0`, broadcast `192.168.1.255`,
254 usable hosts, mask `255.255.255.0`, wildcard `0.0.0.255`, class C / private.

### Subnet Membership
**Purpose**: Tell whether an IP falls inside a given CIDR block, and show that block's range.
**How it works**: Local math — masks both the address and the network to the prefix length and
compares. No network access.
**Example**: IP `192.168.1.50` in `192.168.1.0/24` → **Inside the network**; range
`192.168.1.0 – 192.168.1.255`.

### VLSM Planner
**Purpose**: Carve a base network into right-sized subnets for a list of host requirements.
**How it works**: Sorts your requested subnets largest-first and packs each into the smallest
fitting prefix within the base block — all computed locally.
**Example**: Base `10.0.0.0/24`, needing 50 / 20 / 10 hosts → `10.0.0.0/26`, `10.0.0.64/27`,
`10.0.0.96/28`.

### MAC / OUI Lookup
**Purpose**: Normalize any MAC-address format and identify its hardware vendor offline.
**How it works**: Parses colon/dash/Cisco-dot/raw-hex input and looks up the first 24 bits (OUI)
in a bundled offline vendor database. Randomized/private MACs are flagged rather than named.
**Example**: `3c22.fb01.0203` → normalized `3C:22:FB:01:02:03`, OUI `3C:22:FB`, vendor Apple,
unicast / universally administered.

### Common Ports
**Purpose**: Search a reference list of well-known TCP/UDP ports and services.
**How it works**: A bundled, searchable local database of port numbers, service names, and
descriptions with a TCP/UDP/All filter. No network access.
**Example**: Search `443` → HTTPS (TCP); search `dns` → 53 (TCP/UDP).

### Base Converter
**Purpose**: Convert a number between binary, octal, decimal, and hexadecimal.
**How it works**: Parses the input (prefixes `0x`, `0b`, `0o`, else decimal) into a 64-bit
integer and reformats it in every base locally.
**Example**: `0xFF` → decimal `255`, binary `11111111`, octal `377`.

### Text Converter
**Purpose**: Encode or decode text as Base64, hexadecimal, or URL-percent encoding.
**How it works**: Applies the chosen transform with Foundation's Data/String APIs on-device.
**Example**: `Hi there` → Base64 encode `SGkgdGhlcmU=`; URL-encode of `a b` → `a%20b`.

### Password Generator
**Purpose**: Generate strong random passwords and Wi-Fi keys.
**How it works**: Draws from the selected character sets (upper/lower/digits/symbols) using a
cryptographically secure RNG and estimates entropy in bits locally.
**Example**: Length 16, all sets → e.g. `q7$Kf2!mVz9@Lp0R`, strength **Excellent** (~104 bits).

### QR Generator
**Purpose**: Turn any text or URL into a QR code.
**How it works**: Renders the string to a QR image with Core Image's `CIQRCodeGenerator` on-device.
**Example**: `https://example.com` → a scannable QR image you can copy or share.

### Hash & JWT
**Purpose**: Compute common hashes of text, or decode and inspect a JWT.
**How it works**: Hashes (MD5, SHA-1/256/384/512) are computed with CryptoKit. JWTs are
Base64URL-decoded to show header and payload — the signature is **not** verified. Nothing is uploaded.
**Example**: Text `abc` → SHA-256 `ba7816bf8f01cfea…`; paste a JWT → decoded algorithm, claims,
and expiry status.

### Hash Identifier
**Purpose**: Guess which algorithm produced a given hash string.
**How it works**: Matches the hash's length and character set against known formats locally;
several algorithms can share a length, so results are candidates, not proof.
**Example**: `5f4dcc3b5aa765d61d8327deb882cf99` (32 hex) → likely **MD5 / NTLM / MD4**.

### EUI-64 / SLAAC
**Purpose**: Build the modified EUI-64 interface identifier and SLAAC address from a MAC.
**How it works**: Inserts `FFFE` into the MAC, flips the U/L bit, and appends the result to the
given IPv6 prefix — all computed locally.
**Example**: MAC `3C:22:FB:11:22:33` + `fe80::/64` → interface id `3e22:fbff:fe11:2233`,
SLAAC `fe80::3e22:fbff:fe11:2233`.

### CIDR Aggregator
**Purpose**: Merge a list of IPs/CIDRs into the smallest equivalent set of blocks.
**How it works**: Sorts and collapses adjacent and contained networks into minimal CIDRs
covering exactly the same addresses — locally.
**Example**: `192.168.0.0/24` + `192.168.1.0/24` → `192.168.0.0/23`.

### Timestamp Converter
**Purpose**: Convert between a Unix timestamp and a human date.
**How it works**: Parses the epoch value (auto-detecting seconds vs milliseconds) and formats it
in UTC, local time, and ISO 8601 locally.
**Example**: `1700000000` → `2023-11-14 22:13:20 UTC` (and your local zone).

### Generators
**Purpose**: Produce a random UUID, a locally-administered MAC, or random hex bytes.
**How it works**: Generates each value on-device with the system RNG.
**Example**: New UUID → `550e8400-e29b-41d4-a716-446655440000`; New MAC → `02:1a:2b:3c:4d:5e`.

### JSON Formatter
**Purpose**: Validate and pretty-print (or minify) JSON.
**How it works**: Parses with Foundation's `JSONSerialization`, re-serializes with sorted keys;
toggle Minify for a compact single line. Local only.
**Example**: `{"b":1,"a":2}` → indented, key-sorted output (or `{"a":2,"b":1}` minified).

### Regex Tester
**Purpose**: Test a regular expression against sample text.
**How it works**: Compiles an ICU / `NSRegularExpression` pattern and lists matches with their
capture groups; supports a case-insensitive flag. Local only.
**Example**: Pattern `\d+` on `ab12cd34` → 2 matches: `12`, `34`.

### URL Parser
**Purpose**: Break a URL into its component parts.
**How it works**: Parses the string with `URLComponents` and shows scheme, host, port, path,
query items, and fragment. Local only.
**Example**: `https://a.com:8080/p?x=1#f` → scheme `https`, host `a.com`, port `8080`,
path `/p`, query `x=1`, fragment `f`.

### Data Calculator
**Purpose**: Estimate transfer time for a file size at a given link speed, and convert size units.
**How it works**: Local arithmetic using both decimal (1000) and binary (1024) units.
**Example**: 1 GB at 100 Mbps → ~80 s transfer; also shown in bytes and megabits.

---

## Diagnostics

### Guide
**Purpose**: In-app, step-by-step help for using every tool and setting up permissions.
**How it works**: Static reference content bundled with the app — no network access.
**Example**: Open Guide → sections on Home & search, key tools, Wi-Fi Shortcut setup, and the
Local Network capability.

### Public IP & ISP
**Purpose**: Show your public IP with geo/ISP details, plus your local interface addresses.
**How it works**: Queries **ipwho.is** over HTTPS for the public IP metadata and reads local
interface addresses from the device.
**Example**: → `203.0.113.5`, Country/City, ISP, ASN; local `192.168.1.20`, `fe80::…`.

### IP Info Lookup
**Purpose**: Look up geo and ISP details for any IP or hostname.
**How it works**: Queries **ipwho.is** over HTTPS for the entered address.
**Example**: `8.8.8.8` → United States, Google LLC, AS15169, coordinates.

### Host → IP
**Purpose**: Resolve a hostname to its IPv4 and IPv6 addresses.
**How it works**: Uses the system resolver (`getaddrinfo`) — the same path apps normally use.
**Example**: `apple.com` → `17.253.144.10` and IPv6 addresses.

### Speed Test
**Purpose**: Measure latency, jitter, download, and upload throughput.
**How it works**: Runs against **Cloudflare's open speed endpoints** (the same infrastructure as
speed.cloudflare.com). Briefly uses significant bandwidth.
**Example**: → 250 Mbps down, 40 Mbps up, 12 ms ping, 3 ms jitter.

### HTTP Request
**Purpose**: Send a custom HTTP request (a mini API client).
**How it works**: Builds a request with your method, headers, and body and sends it via
`URLSession`, showing status, response headers, and body.
**Example**: `GET https://api.github.com` → `200`, headers, JSON body.

### History
**Purpose**: See recent runs from across the tools.
**How it works**: A local, on-device log of runs from Subnet, DNS, WHOIS, IP and other tools;
copy, share, export, or clear it. No network access.
**Example**: Recent list shows your last DNS lookup, subnet calc, and WHOIS query.

### Backup & Restore
**Purpose**: Export and restore your saved data as a JSON file.
**How it works**: Serializes saved hosts, SSH profiles, cameras, and speed history to a local
file, with optional password encryption. Stored on-device.
**Example**: Create backup → `.json` file; restore replaces current data (password required if encrypted).

### Ping (TCP)
**Purpose**: Measure reachability and latency to a host.
**How it works**: Sends real ICMP/ICMPv6 echo over the unprivileged datagram socket; when ICMP is
filtered it automatically times a **TCP handshake** to a fallback port instead. Tunable count,
period, timeout, payload, TTL.
**Example**: `1.1.1.1` → avg 12 ms, min 10 / max 15 ms, 0% loss.

### World Ping
**Purpose**: Ping a target from probes distributed around the globe.
**How it works**: Uses the free **globalping.io** network (`api.globalping.io`) — no local ICMP.
Each row shows a probe's location, network, min/avg/max latency, and loss.
**Example**: `1.1.1.1` → London 3 ms, Tokyo 2 ms, São Paulo 4 ms, 0% loss.

### Traceroute
**Purpose**: Trace the network path (hops) to a host.
**How it works**: Sends ICMP echo with increasing TTL; routers that don't reply show as `*`. If
ICMP is fully blocked, a **TCP probe** confirms reachability and hop distance instead.
**Example**: `8.8.8.8` → hop-by-hop list ending at the destination, with per-hop RTT.

### MTR Path Analysis
**Purpose**: Continuous traceroute combining per-hop packet loss and latency.
**How it works**: Sends probes to every hop each round and tracks last/avg/best/worst latency,
loss, and the origin AS per hop.
**Example**: `apple.com` → hop table with `loss 0%`, `avg 14 ms`, plus each hop's AS.

### Port Scanner
**Purpose**: Check which TCP ports are open on a host.
**How it works**: Attempts a TCP handshake to each port in the chosen set (Common / Web / All /
Custom range). Only scan hosts you're authorized to test.
**Example**: Host + Common preset → `22`, `80`, `443` open.

### DNS Lookup
**Purpose**: Resolve A, AAAA, MX, TXT, and other record types.
**How it works**: Builds a raw DNS query and sends it over **UDP to port 53** of the chosen
server (default `1.1.1.1`), then parses the answer.
**Example**: `apple.com` A → `17.253.144.10`.

### DNS over HTTPS
**Purpose**: Resolve DNS privately over an encrypted HTTPS channel.
**How it works**: Sends the query to **Cloudflare's DoH endpoint** (`cloudflare-dns.com`) over HTTPS.
**Example**: `example.com` A → `93.184.216.34`, resolved over HTTPS.

### DNS Compare
**Purpose**: Compare a domain's answers across public resolvers to spot divergence.
**How it works**: Queries **Cloudflare, Google, Quad9, and AdGuard** over DNS-over-HTTPS in
parallel and compares. Divergence can mean propagation lag, geo answers, or filtering.
**Example**: `example.com` → **All resolvers agree** on `93.184.216.34`.

### DNS Stability
**Purpose**: Detect intermittent DNS resolution problems over time.
**How it works**: Repeatedly resolves the hostname against the chosen server at a set interval,
flagging timeouts (drops) and latency spikes, and plotting a timeline.
**Example**: Monitor `apple.com` every 5 s → **Stable**, 0 drops, avg 18 ms, jitter 4 ms.

### DNS Health
**Purpose**: Check DNSSEC validation and propagation consistency for a domain.
**How it works**: Queries through **Cloudflare's validating resolver** with the DO bit (a signed,
valid zone sets the AD flag) and cross-checks several public resolvers for consistency.
**Example**: `cloudflare.com` → **Signed and validated**, consistent across resolvers.

### Email Security
**Purpose**: Verify the SPF, DMARC, and DKIM records that authenticate a domain's mail.
**How it works**: Looks up the relevant TXT records (DKIM needs the correct selector, e.g.
`default`, `google`, `s1`). Missing records make spoofing easier.
**Example**: `example.com` → SPF **Present**, DMARC **Present**, DKIM `google` **Present**.

### Pwned Password
**Purpose**: Check whether a password appears in known breaches.
**How it works**: Uses **Have I Been Pwned's k-anonymity range API** (`api.pwnedpasswords.com`) —
only the first 5 characters of the password's SHA-1 are sent, never the password or full hash.
**Example**: `password` → **Found in breaches** (appears millions of times); a strong unique one → **Not found**.

### Cert Transparency
**Purpose**: Find every TLS certificate ever issued for a domain.
**How it works**: Searches public Certificate Transparency logs via **crt.sh** — useful to
uncover forgotten subdomains or unexpected (rogue) certificates.
**Example**: `example.com` → list of issued certs, issuers, and discovered subdomains.

### WHOIS
**Purpose**: Fetch a domain's registration and ownership record.
**How it works**: Connects to WHOIS servers over **TCP port 43**, following the IANA referral
chain to the authoritative registrar, and parses the record.
**Example**: `example.com` → registrar, created/updated/expires dates, name servers.

### RDAP Lookup
**Purpose**: Structured (JSON) successor to WHOIS for domains and IPs.
**How it works**: Queried via the **rdap.org** bootstrap, which routes to the authoritative
registry and returns structured JSON.
**Example**: `example.com` → handle, registrar, status, events, name servers.

### Banner Grab
**Purpose**: Read the banner a TCP service returns on connect.
**How it works**: Opens a TCP connection and displays whatever the service sends; you can send an
optional probe line (e.g. `GET / HTTP/1.0`) for HTTP. Authorized hosts only.
**Example**: `host:22` (no probe) → `SSH-2.0-OpenSSH_8.9`.

### Service Fingerprint
**Purpose**: Identify the service and software behind a host:port.
**How it works**: Connects, reads the greeting (or an HTTP response), and matches it against
well-known banner patterns — a best-effort heuristic, not a full scan.
**Example**: `host:80` → Service **HTTP**, Product **nginx 1.18.0**.

### HTTP Timing
**Purpose**: Break an HTTP request into its timing phases.
**How it works**: Uses `URLSession` transaction metrics to split the request into DNS, connect,
TLS, request, wait (server/TTFB), and download phases.
**Example**: `https://example.com` → DNS 8 ms, connect 20 ms, TLS 40 ms, wait 60 ms, download 15 ms.

### Uptime Check
**Purpose**: Batch-check reachability and latency for a list of URLs.
**How it works**: Requests each URL once with `URLSession` and reports HTTP status and latency
(green for 2xx/3xx). A single failed request isn't proof a site is down.
**Example**: 3 URLs → all `200`, ~120 ms each.

### Cert Expiry Monitor
**Purpose**: Track TLS certificate expiry across a list of hosts.
**How it works**: Opens a TLS handshake to each host on **port 443** and reports days until the
leaf certificate expires (amber under 30 days, red under 15 or expired).
**Example**: `example.com` → **245 days** remaining.

### nslookup
**Purpose**: Forward and reverse DNS resolution in one tool.
**How it works**: Auto-detects the input — forward lookups use `getaddrinfo`; an IP triggers a
reverse (PTR) lookup via `getnameinfo`.
**Example**: `8.8.8.8` → reverse `dns.google`; `apple.com` → its A/AAAA addresses.

### SSL/TLS Checker
**Purpose**: Inspect a server's TLS certificate, chain, and expiry.
**How it works**: Opens a TLS handshake to the host, reads the leaf certificate and chain, and
assigns a grade based on protocols, key strength, trust, and expiry.
**Example**: `apple.com` → subject/issuer, valid until, chain length, TLS grade **A**, Trusted.

### HTTP Headers
**Purpose**: Inspect the HTTP status and response headers of a URL.
**How it works**: Issues a request with `URLSession` and lists the status code, final URL (after
redirects), and all response headers.
**Example**: `example.com` → `200`, `Server`, `Content-Type`, `Cache-Control` headers.

### Email Validator
**Purpose**: Check an email address's syntax and its domain's mail deliverability.
**How it works**: Validates the address syntax, then looks up the domain's **MX records** to
confirm it can receive mail.
**Example**: `name@example.com` → valid syntax, **Domain accepts mail** (MX records listed).

### Blacklist Check
**Purpose**: Check an IP against DNS blacklists (RBLs).
**How it works**: Reverses the IP and queries several public **DNSBL** zones; a listing can hurt
mail-delivery reputation.
**Example**: `1.2.3.4` → **Not listed** across the checked blacklists.

### NTP Time
**Purpose**: Query a network time server and show your clock offset.
**How it works**: Sends an **SNTP (RFC 4330) request over UDP** and computes offset = server time
minus this device's clock.
**Example**: `time.apple.com` → server time plus a **+0.03 s** clock offset.

### Engine Self-Tests
**Purpose**: Verify the app's calculation engines on your own device.
**How it works**: Runs the same test vectors as the developer's unit tests (subnetting, IPv6,
MAC/OUI, DNS, SNMP encoding, WoL, X.509 dates, VLSM, and more) — entirely local.
**Example**: Run tests → **All passed**.

---

## Local Network

### Network Overview
**Purpose**: See your connection type, public IP, and local addresses at a glance.
**How it works**: Reads the current connection status and local interface addresses on-device and
fetches the public IP over HTTPS.
**Example**: → Wi-Fi, public `203.0.113.5`, local `192.168.1.20`.

### Wi-Fi Info
**Purpose**: Show your connection type, device IP, and router (gateway) address.
**How it works**: Reads what iOS permits on-device (radio details and SSID/BSSID are blocked for
all apps; an optional Shortcut workaround can retrieve the SSID).
**Example**: → Wi-Fi, device IP `192.168.1.20`, gateway `192.168.1.1`, router vendor.

### Saved Hosts
**Purpose**: Bookmark hosts for quick reuse across tools.
**How it works**: Stores names, addresses, and notes locally on-device. No network access.
**Example**: Save `router — 192.168.1.1` → reuse it in Ping, SSH, Port Scanner, etc.

### LAN Scanner
**Purpose**: Discover devices advertising Bonjour services on your network.
**How it works**: Uses Bonjour (`NWBrowser`) to browse service types for a few seconds. Requires
the **Local Network permission**; only devices advertising Bonjour appear (use the IP Range
Scanner to find every host).
**Example**: → Apple TV (`_airplay._tcp`), printer (`_ipp._tcp`), NAS (`_smb._tcp`).

### SSDP / UPnP Discovery
**Purpose**: Find UPnP devices on the local network.
**How it works**: Sends an SSDP **M-SEARCH** to the multicast group and lists responders with
address, server, location URL, and type. Requires the **Local Network permission** and Apple's
multicast entitlement.
**Example**: → router and smart TV with their `Server` strings and description URLs.

### IP Range Scanner
**Purpose**: Ping-sweep a CIDR range to find live hosts.
**How it works**: Probes each address in the CIDR (max 1024) with **ICMP and a TCP handshake**, so
it finds hosts even when ICMP is filtered. The range is pre-filled from your Wi-Fi; local subnets
need the **Local Network permission**.
**Example**: `192.168.1.0/24` → live: `192.168.1.1`, `.20`, `.35`.

### Wake-on-LAN
**Purpose**: Wake a sleeping device by sending a magic packet.
**How it works**: Broadcasts a **UDP magic packet** containing the target's MAC on the local
network. The device must have WoL enabled in its BIOS/firmware.
**Example**: MAC `AA:BB:CC:DD:EE:FF` → **Magic packet sent** to the broadcast address.

### IP Cameras
**Purpose**: Live-view and control IP cameras over RTSP/ONVIF.
**How it works**: Speaks **RTSP over TCP** and decodes H.264/H.265 in hardware — no external
player. ONVIF can auto-fill stream settings; streams keep running while you use other tools.
Requires the **Local Network permission**.
**Example**: `rtsp://192.168.1.50/stream1` → live view, snapshot, PTZ controls.

### Wi-Fi QR Code
**Purpose**: Generate a QR code that lets others join a Wi-Fi network.
**How it works**: Encodes the SSID, security type, and password into the standard Wi-Fi QR format
and renders it on-device. Scan before sharing to keep the password private.
**Example**: SSID `Home`, WPA, password `••••` → a QR a phone camera can join from.

### WireGuard QR
**Purpose**: Build a WireGuard tunnel config and encode it as an importable QR.
**How it works**: Generates the Curve25519 keypair **on-device**, assembles the interface/peer
config, and renders a QR the official WireGuard app imports (Add tunnel → Create from QR code).
Nothing is uploaded.
**Example**: Interface + peer/endpoint fields → a QR that provisions the tunnel in one scan.

---

## Professional

### SSH
**Purpose**: Run a command over SSH.
**How it works**: A native SSH-2 client (curve25519-sha256 key exchange, `aes256-gcm@openssh.com`,
password or ed25519-key auth) built entirely on **CryptoKit** — no external libraries. Runs one
command per session; verify the host-key fingerprint on first connect.
**Example**: `host:22`, run `uname -a` → the command output plus the verified host-key fingerprint.

### SFTP
**Purpose**: Browse and download files over SFTP.
**How it works**: Runs the SFTP subsystem over the same native SSH transport. Tap a folder to
open it, a file to download it. Read-only; password or unencrypted ed25519 key.
**Example**: Browse `/etc` → tap `hosts` to download it to the app's Documents.

### Telnet
**Purpose**: Interactive plaintext TCP terminal.
**How it works**: Opens a raw TCP connection and streams your typed commands and the server's
output. **Unencrypted** — use on trusted local networks only; prefer SSH otherwise.
**Example**: Connect `host:23` → type commands and watch replies live.

### FTP
**Purpose**: Connect and list a directory over FTP.
**How it works**: Plaintext FTP in **passive mode (PASV)**; credentials are sent unencrypted
(default anonymous login). Trusted networks only.
**Example**: `host`, anonymous → the directory listing for the chosen path.

### WebSocket
**Purpose**: Open a WebSocket and exchange frames.
**How it works**: Uses the native `URLSessionWebSocketTask`. Send text frames and watch replies
live; the connection persists while you use other tools.
**Example**: `wss://echo.websocket.org` → send `hi`, receive `hi`.

### MQTT Client
**Purpose**: Publish and subscribe on an MQTT broker.
**How it works**: A native **MQTT 3.1.1** client over TCP/TLS (QoS 0). Connect, subscribe to a
topic, and publish; incoming messages stream live. Connection persists across tools.
**Example**: Connect broker → subscribe `test/topic`, publish `hello` → it echoes back in the log.

### Redis
**Purpose**: Send a single command to a Redis server.
**How it works**: Speaks the Redis **RESP** protocol over TCP and formats the reply; `AUTH` is
sent first when a password is provided. Authorized servers only.
**Example**: `PING` → `PONG`; `INFO server` → the server section text.

### Modbus TCP
**Purpose**: Read holding or input registers from a Modbus TCP device.
**How it works**: Sends a **Modbus TCP** request (port 502) for holding (FC3) or input (FC4)
registers and shows the values in decimal and hex.
**Example**: Read 2 holding registers from address `0` → `[230, 0x00E6]`, `[12, 0x000C]`.

### SMTP Probe
**Purpose**: Inspect a mail server's banner and advertised capabilities.
**How it works**: Connects and runs an **EHLO** handshake on port 25/587 (plain) or 465 (TLS),
showing the banner and capability list.
**Example**: `mail.example.com:587` → banner plus `STARTTLS`, `SIZE`, `AUTH` capabilities.

### Memcached
**Purpose**: Read version and stats from a memcached server.
**How it works**: Sends `version` and `stats` over the **memcached text protocol** and shows the
raw output. Authorized servers only.
**Example**: `host:11211` → version string and the full stats block.

### CoAP Client
**Purpose**: Send a CoAP GET to an IoT device.
**How it works**: Sends a confirmable **CoAP GET (RFC 7252) over UDP** (port 5683) and shows the
response code and payload. Authorized devices only.
**Example**: Path `.well-known/core` → `2.05 Content` with the resource listing.

### TFTP Client
**Purpose**: Download a file from a TFTP server.
**How it works**: Reads a file over **TFTP (UDP port 69)** using a raw socket to follow the
transfer-ID port, saving it to the app's Documents (2 MB limit).
**Example**: File `config.txt` → downloaded and saved locally.

### Syslog Receiver
**Purpose**: Receive syslog messages from your devices.
**How it works**: Listens for **syslog UDP datagrams** and shows the sender and severity. Use a
non-privileged port (e.g. 5140) since binding 514 may be blocked on iOS.
**Example**: Listen on `5140` → incoming lines with sender IP and severity.

### SNMP Trap Receiver
**Purpose**: Receive SNMP traps from your devices.
**How it works**: Listens for **SNMP trap UDP datagrams** and shows the sender, version/community,
and a hex preview. Use a non-privileged port (e.g. 1162); binding 162 may be blocked.
**Example**: Point a switch at port `1162` → trap sender, community, and hex payload.

### MikroTik API
**Purpose**: Run RouterOS API commands on a MikroTik router.
**How it works**: Uses the **RouterOS API** (port 8728) with plain login (RouterOS 6.43+). Enable
the API service and use a dedicated account.
**Example**: `/system/resource/print` → CPU load, uptime, and version records.

### SNMP GET
**Purpose**: Query SNMP OIDs on a network device.
**How it works**: Sends an **SNMP v2c** GET for one OID, a Walk to enumerate a subtree, or a v3
(USM authNoPriv) request; port and community are configurable, with common-OID presets.
**Example**: OID `1.3.6.1.2.1.1.1.0` → the device's `sysDescr` string.

### iperf3 Speed Test
**Purpose**: Measure TCP throughput to an iperf3 server.
**How it works**: Connects to a reachable **iperf3 3.x** server (default port 5201, run
`iperf3 -s` on the host) and runs a TCP download or upload test with configurable duration and
parallel streams. TCP only, no authentication.
**Example**: Host + 10 s download → ~450 Mbps transferred over the interval.

---

## BGP

### ASN Info
**Purpose**: Look up an autonomous system's holder, prefixes, and neighbours.
**How it works**: Queries the public **RIPEstat API** (`stat.ripe.net`, RIPE NCC) — a routing
looking glass, no login needed.
**Example**: `AS15169` → holder Google LLC, announced-prefix count, BGP neighbour count.

### IP → BGP
**Purpose**: Resolve an IP or prefix to its covering BGP prefix and origin AS.
**How it works**: Queries the public **RIPEstat API** for the routing data behind the address.
**Example**: `8.8.8.8` → prefix `8.8.8.0/24`, origin `AS15169`.

### RPKI Validator
**Purpose**: Check whether an origin AS is authorized to announce a prefix.
**How it works**: Validates the prefix + origin AS against the Route Origin Authorizations (ROAs)
in the RPKI via the public **RIPEstat API**.
**Example**: `AS13335` + `104.16.0.0/12` → **Valid**.
