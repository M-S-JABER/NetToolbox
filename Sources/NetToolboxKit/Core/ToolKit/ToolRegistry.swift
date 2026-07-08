import SwiftUI

/// Single source of truth for every tool in the app.
/// The home screen builds itself from this list — register a tool here
/// and it appears in its category with navigation wired up.
@MainActor
enum ToolRegistry {
    static let all: [any NetworkTool] = [
        // Phase 1 — calculators & reference
        SubnetCalculatorTool(),
        SubnetMembershipTool(),
        VLSMTool(),
        MACLookupTool(),
        PortReferenceTool(),
        NumberConverterTool(),
        TextConverterTool(),
        PasswordGeneratorTool(),
        QRGeneratorTool(),
        CryptoToolboxTool(),
        HashIDTool(),
        EUI64Tool(),
        CIDRAggregateTool(),
        TimestampTool(),
        GeneratorsTool(),
        JSONFormatterTool(),
        RegexTesterTool(),
        URLParserTool(),
        DataCalcTool(),
        // Phase 2 — diagnostics
        GuideTool(),
        PublicIPTool(),
        IPInfoTool(),
        HostToIPTool(),
        SpeedTestTool(),
        HTTPRequestTool(),
        HistoryTool(),
        BackupTool(),
        PingTool(),
        WorldPingTool(),
        TracerouteTool(),
        MTRTool(),
        PortScannerTool(),
        DNSLookupTool(),
        DoHTool(),
        DNSCompareTool(),
        DNSReliabilityTool(),
        EmailSecurityTool(),
        PwnedCheckTool(),
        CertTransparencyTool(),
        WhoisTool(),
        RDAPTool(),
        BannerGrabTool(),
        HTTPTimingTool(),
        UptimeTool(),
        NSLookupTool(),
        SSLCheckerTool(),
        HTTPHeadersTool(),
        EmailValidatorTool(),
        RBLCheckTool(),
        NTPTool(),
        SelfTestTool(),
        // Phase 2 — local network
        NetworkOverviewTool(),
        WiFiInfoTool(),
        SavedHostsTool(),
        LANScannerTool(),
        IPRangeScannerTool(),
        WakeOnLANTool(),
        CameraTool(),
        WiFiQRTool(),
        WireGuardQRTool(),
        // Phase 3 — professional
        SSHTool(),
        SFTPTool(),
        TelnetTool(),
        FTPTool(),
        WebSocketTool(),
        MQTTTool(),
        RedisTool(),
        ModbusTool(),
        SMTPTool(),
        MemcachedTool(),
        CoAPTool(),
        TFTPTool(),
        SyslogTool(),
        SNMPTrapTool(),
        MikroTikAPITool(),
        SNMPTool(),
        // BGP / global routing (RIPEstat)
        ASNInfoTool(),
        IPBGPTool(),
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
