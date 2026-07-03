import SwiftUI
import Observation
#if canImport(UIKit)
import UIKit
import CoreImage
#endif

/// Builds Wi-Fi network QR payloads (the `WIFI:` URI scheme) and renders
/// them. The payload builder is pure and unit-tested.
enum WiFiQR {
    enum Security: String, CaseIterable, Identifiable, Sendable {
        case wpa = "WPA"
        case wep = "WEP"
        case none = "nopass"

        var id: String { rawValue }
        var labelKey: String { "wifiqr.security.\(rawValue)" }
    }

    /// Escapes the special characters `\ ; , : "` used by the WIFI: scheme.
    static func escape(_ value: String) -> String {
        var result = ""
        for character in value {
            if "\\;,:\"".contains(character) {
                result.append("\\")
            }
            result.append(character)
        }
        return result
    }

    /// Produces a `WIFI:T:…;S:…;P:…;H:…;;` payload string.
    static func payload(ssid: String, security: Security, password: String, hidden: Bool) -> String {
        let escapedSSID = escape(ssid)
        let hiddenField = hidden ? "true" : "false"
        if security == .none {
            return "WIFI:T:nopass;S:\(escapedSSID);H:\(hiddenField);;"
        }
        let escapedPassword = escape(password)
        return "WIFI:T:\(security.rawValue);S:\(escapedSSID);P:\(escapedPassword);H:\(hiddenField);;"
    }

    #if canImport(UIKit)
    /// Renders a payload string to a crisp QR `UIImage`.
    static func image(from payload: String) -> UIImage? {
        QRCode.image(from: payload)
    }
    #endif
}

@MainActor
@Observable
final class WiFiQRViewModel {
    var ssid = ""
    var password = ""
    var security: WiFiQR.Security = .wpa
    var hidden = false

    var payload: String {
        WiFiQR.payload(ssid: ssid, security: security, password: password, hidden: hidden)
    }
}

struct WiFiQRTool: NetworkTool {
    let id = "wifi-qr"
    let titleKey = L10n("tool.wifiqr.title")
    let subtitleKey = L10n("tool.wifiqr.subtitle")
    let systemImage = "qrcode"
    let category: ToolCategory = .localNetwork

    func makeView() -> AnyView { AnyView(WiFiQRView()) }
}

struct WiFiQRView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = WiFiQRViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if !viewModel.ssid.isEmpty {
                    qrSection
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.wifiqr.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("wifiqr.input.title"), systemImage: "wifi") {
            TextField(L10nString("wifiqr.input.ssid"), text: $viewModel.ssid)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)

            Picker(L10nString("wifiqr.security.title"), selection: $viewModel.security) {
                ForEach(WiFiQR.Security.allCases) { security in
                    Text(L10n(security.labelKey)).tag(security)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.security != .none {
                SecureField(L10nString("wifiqr.input.password"), text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .environment(\.layoutDirection, .leftToRight)
            }

            Toggle(isOn: $viewModel.hidden) {
                Text(L10n("wifiqr.hidden"))
                    .font(AppTypography.body)
                    .foregroundStyle(theme.textPrimary)
            }
        }
    }

    @ViewBuilder
    private var qrSection: some View {
        SectionCard(title: L10n("wifiqr.section.code"), systemImage: "qrcode") {
            #if canImport(UIKit)
            if let image = WiFiQR.image(from: viewModel.payload) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260)
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(Color.white)
                    )
            }
            #endif
            Text(L10n("wifiqr.note"))
                .font(AppTypography.caption)
                .foregroundStyle(theme.textSecondary)
        }
    }
}
