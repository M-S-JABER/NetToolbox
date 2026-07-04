import SwiftUI

/// Single source of truth for every tool in the app.
/// The home screen builds itself from this list — register a tool here
/// and it appears in its category with navigation wired up.
@MainActor
enum ToolRegistry {
    static let all: [any NetworkTool] = [
        // Phase 1 — calculators & reference
        SubnetCalculatorTool(),
        VLSMTool(),
        MACLookupTool(),
        PortReferenceTool(),
        NumberConverterTool(),
        TextConverterTool(),
        PasswordGeneratorTool(),
        QRGeneratorTool(),
        // Phase 2 — diagnostics
        PublicIPTool(),
        IPInfoTool(),
        HostToIPTool(),
        SpeedTestTool(),
        HistoryTool(),
        PingTool(),
        TracerouteTool(),
        PortScannerTool(),
        DNSLookupTool(),
        WhoisTool(),
        SSLCheckerTool(),
        HTTPHeadersTool(),
        NTPTool(),
        SelfTestTool(),
        // Phase 2 — local network
        NetworkOverviewTool(),
        LANScannerTool(),
        IPRangeScannerTool(),
        WakeOnLANTool(),
        WiFiQRTool(),
        // Phase 3 — professional
        TelnetTool(),
        MikroTikAPITool(),
        SNMPTool(),
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
