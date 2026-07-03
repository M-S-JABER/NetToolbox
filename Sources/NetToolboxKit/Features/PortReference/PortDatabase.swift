import Foundation

/// Transport protocols a port entry applies to.
enum TransportProtocol: String, CaseIterable, Identifiable, Sendable {
    case tcp = "TCP"
    case udp = "UDP"
    var id: String { rawValue }
}

/// A well-known port reference entry. Service names and descriptions are
/// technical vocabulary and intentionally stay in English.
struct PortEntry: Identifiable, Sendable {
    let port: Int
    let protocols: [TransportProtocol]
    let service: String
    let summary: String

    var id: String { "\(port)-\(service)" }

    func matches(query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let q = query.lowercased()
        return String(port).hasPrefix(q)
            || service.lowercased().contains(q)
            || summary.lowercased().contains(q)
    }
}

/// Offline reference of common TCP/UDP ports.
enum PortDatabase {
    static let all: [PortEntry] = [
        PortEntry(port: 20, protocols: [.tcp], service: "FTP-DATA", summary: "File Transfer Protocol — data channel"),
        PortEntry(port: 21, protocols: [.tcp], service: "FTP", summary: "File Transfer Protocol — control channel"),
        PortEntry(port: 22, protocols: [.tcp], service: "SSH", summary: "Secure Shell — remote login, SFTP, tunneling"),
        PortEntry(port: 23, protocols: [.tcp], service: "Telnet", summary: "Unencrypted remote terminal (legacy)"),
        PortEntry(port: 25, protocols: [.tcp], service: "SMTP", summary: "Mail transfer between servers"),
        PortEntry(port: 53, protocols: [.tcp, .udp], service: "DNS", summary: "Domain Name System queries and zone transfers"),
        PortEntry(port: 67, protocols: [.udp], service: "DHCP", summary: "DHCP server (BOOTP)"),
        PortEntry(port: 68, protocols: [.udp], service: "DHCP", summary: "DHCP client (BOOTP)"),
        PortEntry(port: 69, protocols: [.udp], service: "TFTP", summary: "Trivial FTP — firmware and config transfer"),
        PortEntry(port: 80, protocols: [.tcp], service: "HTTP", summary: "Web traffic (unencrypted)"),
        PortEntry(port: 88, protocols: [.tcp, .udp], service: "Kerberos", summary: "Kerberos authentication"),
        PortEntry(port: 110, protocols: [.tcp], service: "POP3", summary: "Mail retrieval (legacy)"),
        PortEntry(port: 111, protocols: [.tcp, .udp], service: "RPCbind", summary: "ONC RPC portmapper (NFS)"),
        PortEntry(port: 119, protocols: [.tcp], service: "NNTP", summary: "Usenet news transfer"),
        PortEntry(port: 123, protocols: [.udp], service: "NTP", summary: "Network Time Protocol"),
        PortEntry(port: 135, protocols: [.tcp, .udp], service: "MS RPC", summary: "Microsoft RPC endpoint mapper"),
        PortEntry(port: 137, protocols: [.udp], service: "NetBIOS-NS", summary: "NetBIOS name service"),
        PortEntry(port: 138, protocols: [.udp], service: "NetBIOS-DGM", summary: "NetBIOS datagram service"),
        PortEntry(port: 139, protocols: [.tcp], service: "NetBIOS-SSN", summary: "NetBIOS session service (SMB over NetBIOS)"),
        PortEntry(port: 143, protocols: [.tcp], service: "IMAP", summary: "Mail retrieval with server-side folders"),
        PortEntry(port: 161, protocols: [.udp], service: "SNMP", summary: "Network monitoring — agent queries"),
        PortEntry(port: 162, protocols: [.udp], service: "SNMP-TRAP", summary: "SNMP traps and notifications"),
        PortEntry(port: 179, protocols: [.tcp], service: "BGP", summary: "Border Gateway Protocol routing"),
        PortEntry(port: 194, protocols: [.tcp], service: "IRC", summary: "Internet Relay Chat"),
        PortEntry(port: 389, protocols: [.tcp, .udp], service: "LDAP", summary: "Directory services"),
        PortEntry(port: 443, protocols: [.tcp, .udp], service: "HTTPS", summary: "Web traffic over TLS; UDP = HTTP/3 (QUIC)"),
        PortEntry(port: 445, protocols: [.tcp], service: "SMB", summary: "Windows file sharing (direct SMB)"),
        PortEntry(port: 465, protocols: [.tcp], service: "SMTPS", summary: "Mail submission over implicit TLS"),
        PortEntry(port: 500, protocols: [.udp], service: "IKE", summary: "IPsec key exchange (ISAKMP)"),
        PortEntry(port: 514, protocols: [.udp], service: "Syslog", summary: "System logging"),
        PortEntry(port: 515, protocols: [.tcp], service: "LPD", summary: "Line printer daemon"),
        PortEntry(port: 520, protocols: [.udp], service: "RIP", summary: "Routing Information Protocol"),
        PortEntry(port: 546, protocols: [.udp], service: "DHCPv6", summary: "DHCPv6 client"),
        PortEntry(port: 547, protocols: [.udp], service: "DHCPv6", summary: "DHCPv6 server"),
        PortEntry(port: 587, protocols: [.tcp], service: "SMTP", summary: "Mail submission with STARTTLS"),
        PortEntry(port: 631, protocols: [.tcp, .udp], service: "IPP", summary: "Internet Printing Protocol (CUPS/AirPrint)"),
        PortEntry(port: 636, protocols: [.tcp], service: "LDAPS", summary: "LDAP over TLS"),
        PortEntry(port: 853, protocols: [.tcp, .udp], service: "DoT", summary: "DNS over TLS / DNS over QUIC"),
        PortEntry(port: 873, protocols: [.tcp], service: "rsync", summary: "rsync file synchronization daemon"),
        PortEntry(port: 989, protocols: [.tcp], service: "FTPS-DATA", summary: "FTP over TLS — data channel"),
        PortEntry(port: 990, protocols: [.tcp], service: "FTPS", summary: "FTP over TLS — control channel"),
        PortEntry(port: 993, protocols: [.tcp], service: "IMAPS", summary: "IMAP over TLS"),
        PortEntry(port: 995, protocols: [.tcp], service: "POP3S", summary: "POP3 over TLS"),
        PortEntry(port: 1194, protocols: [.tcp, .udp], service: "OpenVPN", summary: "OpenVPN tunnel"),
        PortEntry(port: 1433, protocols: [.tcp], service: "MSSQL", summary: "Microsoft SQL Server"),
        PortEntry(port: 1521, protocols: [.tcp], service: "Oracle", summary: "Oracle database listener"),
        PortEntry(port: 1701, protocols: [.udp], service: "L2TP", summary: "Layer 2 Tunneling Protocol"),
        PortEntry(port: 1723, protocols: [.tcp], service: "PPTP", summary: "PPTP VPN (legacy)"),
        PortEntry(port: 1812, protocols: [.udp], service: "RADIUS", summary: "RADIUS authentication"),
        PortEntry(port: 1813, protocols: [.udp], service: "RADIUS-ACCT", summary: "RADIUS accounting"),
        PortEntry(port: 1883, protocols: [.tcp], service: "MQTT", summary: "IoT message broker"),
        PortEntry(port: 2049, protocols: [.tcp, .udp], service: "NFS", summary: "Network File System"),
        PortEntry(port: 2083, protocols: [.tcp], service: "cPanel", summary: "cPanel over TLS"),
        PortEntry(port: 2222, protocols: [.tcp], service: "SSH-alt", summary: "Common alternative SSH port (DirectAdmin)"),
        PortEntry(port: 3128, protocols: [.tcp], service: "Squid", summary: "HTTP proxy (Squid default)"),
        PortEntry(port: 3260, protocols: [.tcp], service: "iSCSI", summary: "iSCSI target"),
        PortEntry(port: 3306, protocols: [.tcp], service: "MySQL", summary: "MySQL / MariaDB database"),
        PortEntry(port: 3389, protocols: [.tcp, .udp], service: "RDP", summary: "Remote Desktop Protocol"),
        PortEntry(port: 3478, protocols: [.udp], service: "STUN", summary: "NAT traversal for VoIP/WebRTC"),
        PortEntry(port: 4500, protocols: [.udp], service: "IPsec NAT-T", summary: "IPsec NAT traversal"),
        PortEntry(port: 5060, protocols: [.tcp, .udp], service: "SIP", summary: "VoIP signaling"),
        PortEntry(port: 5061, protocols: [.tcp], service: "SIPS", summary: "VoIP signaling over TLS"),
        PortEntry(port: 5432, protocols: [.tcp], service: "PostgreSQL", summary: "PostgreSQL database"),
        PortEntry(port: 5353, protocols: [.udp], service: "mDNS", summary: "Multicast DNS (Bonjour discovery)"),
        PortEntry(port: 5672, protocols: [.tcp], service: "AMQP", summary: "Message queueing (RabbitMQ)"),
        PortEntry(port: 5900, protocols: [.tcp], service: "VNC", summary: "Remote desktop (VNC)"),
        PortEntry(port: 6379, protocols: [.tcp], service: "Redis", summary: "Redis in-memory datastore"),
        PortEntry(port: 6443, protocols: [.tcp], service: "K8s API", summary: "Kubernetes API server"),
        PortEntry(port: 8080, protocols: [.tcp], service: "HTTP-alt", summary: "Alternative HTTP / proxies / dev servers"),
        PortEntry(port: 8291, protocols: [.tcp], service: "Winbox", summary: "MikroTik Winbox management"),
        PortEntry(port: 8443, protocols: [.tcp], service: "HTTPS-alt", summary: "Alternative HTTPS (management UIs)"),
        PortEntry(port: 8728, protocols: [.tcp], service: "MikroTik API", summary: "RouterOS API"),
        PortEntry(port: 8729, protocols: [.tcp], service: "MikroTik API-SSL", summary: "RouterOS API over TLS"),
        PortEntry(port: 9000, protocols: [.tcp], service: "PHP-FPM", summary: "PHP FastCGI / management consoles"),
        PortEntry(port: 9090, protocols: [.tcp], service: "Prometheus", summary: "Prometheus metrics UI"),
        PortEntry(port: 9100, protocols: [.tcp], service: "JetDirect", summary: "Raw printer port / node-exporter"),
        PortEntry(port: 10000, protocols: [.tcp], service: "Webmin", summary: "Webmin server administration"),
        PortEntry(port: 27017, protocols: [.tcp], service: "MongoDB", summary: "MongoDB database"),
        PortEntry(port: 51820, protocols: [.udp], service: "WireGuard", summary: "WireGuard VPN tunnel"),
    ]

    /// Well-known service name for a port number, if any (used by the scanner).
    static func serviceName(for port: Int) -> String? {
        all.first { $0.port == port }?.service
    }
}
