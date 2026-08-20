import SwiftUI

/// Single source of truth for every tool in the app.
/// The home screen builds itself from this list — register a tool here
/// and it appears in its category with navigation wired up.
@MainActor
enum ToolRegistry {
    // Tools are listed strictly grouped by category, and within each group in a
    // logical progression (IP math → converters → generators; addressing →
    // reachability → DNS → web → TLS/cert → identity → utilities; etc.). The
    // sidebar renders each category as its own collapsible section, so this
    // order is exactly what the user sees inside every group.
    static let all: [any NetworkTool] = [
        // MARK: Calculators — subnet/IP math, then converters, then generators
        SubnetCalculatorTool(),
        SubnetMembershipTool(),
        VLSMTool(),
        CIDRAggregateTool(),
        EUI64Tool(),
        MACLookupTool(),
        PortReferenceTool(),
        NumberConverterTool(),
        TextConverterTool(),
        TimestampTool(),
        DataCalcTool(),
        URLParserTool(),
        JSONFormatterTool(),
        RegexTesterTool(),
        PasswordGeneratorTool(),
        GeneratorsTool(),
        QRGeneratorTool(),
        CryptoToolboxTool(),
        HashIDTool(),

        // MARK: Diagnostics — addressing → reachability → ports → HTTP → speed
        // (The user Guide is not a probe — it lives in Settings, not this list.)
        PublicIPTool(),
        IPInfoTool(),
        HostToIPTool(),
        PingTool(),
        TracerouteTool(),
        MTRTool(),
        WorldPingTool(),
        PortScannerTool(),
        BannerGrabTool(),
        FingerprintTool(),
        HTTPRequestTool(),
        HTTPHeadersTool(),
        HTTPTimingTool(),
        SpeedTestTool(),
        UptimeTool(),
        NTPTool(),

        // MARK: DNS & Domains — resolution → comparison → health → registration
        DNSLookupTool(),
        NSLookupTool(),
        DoHTool(),
        DNSCompareTool(),
        DNSReliabilityTool(),
        DNSHealthTool(),
        WhoisTool(),
        RDAPTool(),

        // MARK: Security — TLS/certificates → email authenticity → reputation
        SSLCheckerTool(),
        CertExpiryTool(),
        CertTransparencyTool(),
        EmailSecurityTool(),
        EmailValidatorTool(),
        RBLCheckTool(),
        PwnedCheckTool(),

        // MARK: Local Network — overview → discovery → wake → hosts → camera → QR
        NetworkOverviewTool(),
        WiFiInfoTool(),
        LANScannerTool(),
        IPRangeScannerTool(),
        SSDPTool(),
        WakeOnLANTool(),
        SavedHostsTool(),
        CameraTool(),
        WiFiQRTool(),
        WireGuardQRTool(),

        // MARK: Professional — shells → file transfer → messaging → DB/cache
        //        → industrial/IoT → network mgmt → performance
        SSHTool(),
        TelnetTool(),
        MikroTikAPITool(),
        SFTPTool(),
        FTPTool(),
        TFTPTool(),
        WebSocketTool(),
        MQTTTool(),
        SMTPTool(),
        RedisTool(),
        MemcachedTool(),
        ModbusTool(),
        CoAPTool(),
        SNMPTool(),
        SNMPTrapTool(),
        SyslogTool(),
        IPerf3Tool(),

        // MARK: BGP / global routing (RIPEstat)
        ASNInfoTool(),
        IPBGPTool(),
        RPKITool(),
    ]

    static func tools(in category: ToolCategory) -> [any NetworkTool] {
        all.filter { $0.category == category }
    }

    static func tool(withID id: String) -> (any NetworkTool)? {
        all.first { $0.id == id }
    }

    /// Categories that currently contain at least one tool.
    static var activeCategories: [ToolCategory] {
        ToolCategory.allCases.filter { !tools(in: $0).isEmpty }
    }
}
