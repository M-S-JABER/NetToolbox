import SwiftUI
import Observation
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

/// Builds a WireGuard tunnel configuration and renders it as a QR code the
/// official WireGuard app imports by scanning. Keypairs are generated natively
/// with CryptoKit's Curve25519 — the same curve WireGuard uses — so no external
/// tooling is needed. The config never leaves the device unless you share it.
enum WireGuardQR {
    /// Assembles a `.conf` string from the tunnel fields (empty fields omitted).
    static func config(
        privateKey: String,
        address: String,
        dns: String,
        peerPublicKey: String,
        presharedKey: String,
        endpoint: String,
        allowedIPs: String,
        keepalive: String
    ) -> String {
        var lines = ["[Interface]", "PrivateKey = \(privateKey)"]
        if !address.isEmpty { lines.append("Address = \(address)") }
        if !dns.isEmpty { lines.append("DNS = \(dns)") }

        lines.append("")
        lines.append("[Peer]")
        lines.append("PublicKey = \(peerPublicKey)")
        if !presharedKey.isEmpty { lines.append("PresharedKey = \(presharedKey)") }
        if !endpoint.isEmpty { lines.append("Endpoint = \(endpoint)") }
        if !allowedIPs.isEmpty { lines.append("AllowedIPs = \(allowedIPs)") }
        if !keepalive.isEmpty { lines.append("PersistentKeepalive = \(keepalive)") }
        return lines.joined(separator: "\n")
    }

    /// Generates a fresh Curve25519 keypair, base64-encoded as WireGuard expects.
    static func generateKeypair() -> (privateKey: String, publicKey: String) {
        let key = Curve25519.KeyAgreement.PrivateKey()
        return (
            key.rawRepresentation.base64EncodedString(),
            key.publicKey.rawRepresentation.base64EncodedString()
        )
    }

    /// Derives the public key for a pasted base64 private key (nil if invalid).
    static func publicKey(for privateKeyBase64: String) -> String? {
        let trimmed = privateKeyBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: trimmed),
              let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data) else {
            return nil
        }
        return key.publicKey.rawRepresentation.base64EncodedString()
    }

    #if canImport(UIKit)
    static func image(from payload: String) -> UIImage? {
        QRCode.image(from: payload)
    }
    #endif
}

@MainActor
@Observable
final class WireGuardQRViewModel {
    var privateKey = ""
    var address = "10.0.0.2/32"
    var dns = "1.1.1.1"
    var peerPublicKey = ""
    var presharedKey = ""
    var endpoint = ""
    var allowedIPs = "0.0.0.0/0, ::/0"
    var keepalive = "25"

    /// The interface public key derived from `privateKey` — this is what you
    /// register on the server as the peer's PublicKey.
    var derivedPublicKey: String {
        WireGuardQR.publicKey(for: privateKey) ?? ""
    }

    var isComplete: Bool {
        !privateKey.trimmingCharacters(in: .whitespaces).isEmpty
            && !peerPublicKey.trimmingCharacters(in: .whitespaces).isEmpty
            && !endpoint.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var payload: String {
        WireGuardQR.config(
            privateKey: privateKey.trimmingCharacters(in: .whitespaces),
            address: address.trimmingCharacters(in: .whitespaces),
            dns: dns.trimmingCharacters(in: .whitespaces),
            peerPublicKey: peerPublicKey.trimmingCharacters(in: .whitespaces),
            presharedKey: presharedKey.trimmingCharacters(in: .whitespaces),
            endpoint: endpoint.trimmingCharacters(in: .whitespaces),
            allowedIPs: allowedIPs.trimmingCharacters(in: .whitespaces),
            keepalive: keepalive.trimmingCharacters(in: .whitespaces)
        )
    }

    func generateKeypair() {
        privateKey = WireGuardQR.generateKeypair().privateKey
    }
}

struct WireGuardQRTool: NetworkTool {
    let id = "wireguard-qr"
    let titleKey = L10n("tool.wireguard.title")
    let subtitleKey = L10n("tool.wireguard.subtitle")
    let systemImage = "lock.shield"
    let category: ToolCategory = .localNetwork

    func makeView() -> AnyView { AnyView(WireGuardQRView()) }
}

struct WireGuardQRView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = WireGuardQRViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                interfaceSection
                peerSection
                if viewModel.isComplete {
                    qrSection
                }
                Text(L10n("wireguard.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.wireguard.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var interfaceSection: some View {
        SectionCard(title: L10n("wireguard.section.interface"), systemImage: "person.badge.key") {
            field(L10nString("wireguard.field.privateKey"), text: $viewModel.privateKey)
            Button {
                viewModel.generateKeypair()
            } label: {
                Label(L10nString("wireguard.action.generate"), systemImage: "key.horizontal")
                    .font(AppTypography.footnote)
            }
            .buttonStyle(.bordered)

            if !viewModel.derivedPublicKey.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(L10n("wireguard.field.publicKey"))
                        .font(AppTypography.caption)
                        .foregroundStyle(theme.textSecondary)
                    CopyableValue(value: viewModel.derivedPublicKey, font: AppTypography.monoCaption)
                }
            }

            field(L10nString("wireguard.field.address"), text: $viewModel.address)
            field(L10nString("wireguard.field.dns"), text: $viewModel.dns)
        }
    }

    private var peerSection: some View {
        SectionCard(title: L10n("wireguard.section.peer"), systemImage: "server.rack") {
            field(L10nString("wireguard.field.peerPublicKey"), text: $viewModel.peerPublicKey)
            field(L10nString("wireguard.field.presharedKey"), text: $viewModel.presharedKey)
            field(L10nString("wireguard.field.endpoint"), text: $viewModel.endpoint)
            field(L10nString("wireguard.field.allowedIPs"), text: $viewModel.allowedIPs)
            field(L10nString("wireguard.field.keepalive"), text: $viewModel.keepalive, numeric: true)
        }
    }

    @ViewBuilder
    private var qrSection: some View {
        SectionCard(title: L10n("wireguard.section.qr"), systemImage: "qrcode") {
            #if canImport(UIKit)
            if let image = WireGuardQR.image(from: viewModel.payload) {
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
            Text(viewModel.payload)
                .font(AppTypography.monoCaption)
                .foregroundStyle(theme.textSecondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .leftToRight)
            HStack {
                CopyButton(value: viewModel.payload)
                ShareLink(item: viewModel.payload) {
                    Label(L10nString("common.share"), systemImage: "square.and.arrow.up")
                        .font(AppTypography.footnote)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func field(_ label: String, text: Binding<String>, numeric: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(theme.textSecondary)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoCaption)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(numeric ? .numberPad : .asciiCapable)
                .environment(\.layoutDirection, .leftToRight)
        }
    }
}
