import SwiftUI
import Observation

/// Modbus TCP request encoding + register-response parsing (functions 3 & 4).
enum Modbus {
    static func request(transaction: UInt16, unit: UInt8, function: UInt8, address: UInt16, quantity: UInt16) -> Data {
        let pdu: [UInt8] = [function,
                            UInt8(address >> 8), UInt8(address & 0xFF),
                            UInt8(quantity >> 8), UInt8(quantity & 0xFF)]
        let length = UInt16(pdu.count + 1) // unit id + PDU
        let mbap: [UInt8] = [UInt8(transaction >> 8), UInt8(transaction & 0xFF),
                             0, 0,
                             UInt8(length >> 8), UInt8(length & 0xFF),
                             unit]
        return Data(mbap + pdu)
    }

    enum ParseResult: Equatable { case registers([UInt16]); case exception(UInt8) }

    static func parse(_ data: Data) -> ParseResult? {
        let bytes = [UInt8](data)
        guard bytes.count >= 9 else { return nil }
        let function = bytes[7]
        if function & 0x80 != 0 { return .exception(bytes.count > 8 ? bytes[8] : 0) }
        let byteCount = Int(bytes[8])
        guard bytes.count >= 9 + byteCount else { return nil }
        var registers: [UInt16] = []
        var i = 9
        while i + 1 < 9 + byteCount {
            registers.append(UInt16(bytes[i]) << 8 | UInt16(bytes[i + 1]))
            i += 2
        }
        return .registers(registers)
    }
}

struct ModbusService: Sendable {
    func read(host: String, port: UInt16, unit: UInt8, function: UInt8, address: UInt16, quantity: UInt16) async -> Result<[UInt16], String> {
        guard let connection = TCPConnection(host: host, port: port) else {
            return .failure(L10nString("banner.error.host"))
        }
        if case .failure(let error) = await connection.open(timeout: 6) {
            connection.cancel()
            return .failure(error.localizedDescription)
        }
        _ = await connection.send(Modbus.request(transaction: 1, unit: unit, function: function, address: address, quantity: quantity))
        let result = await connection.receive()
        connection.cancel()
        switch result {
        case .success(let data):
            switch Modbus.parse(data) {
            case .registers(let regs): return .success(regs)
            case .exception(let code): return .failure(String(format: L10nString("modbus.exception"), Int(code)))
            case .none: return .failure(L10nString("modbus.badResponse"))
            }
        case .failure(let error):
            return .failure(error.localizedDescription)
        }
    }
}

@MainActor
@Observable
final class ModbusViewModel {
    var host = ""
    var portText = "502"
    var unitText = "1"
    var function = 3
    var addressText = "0"
    var quantityText = "10"
    private(set) var registers: [UInt16] = []
    private(set) var errorMessage: String?
    private(set) var isRunning = false

    private let service = ModbusService()

    func run() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty, let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) else { return }
        isRunning = true
        errorMessage = nil
        registers = []
        let result = await service.read(
            host: target, port: port,
            unit: UInt8(unitText.trimmingCharacters(in: .whitespaces)) ?? 1,
            function: function == 4 ? 4 : 3,
            address: UInt16(addressText.trimmingCharacters(in: .whitespaces)) ?? 0,
            quantity: max(1, min(125, UInt16(quantityText.trimmingCharacters(in: .whitespaces)) ?? 10))
        )
        switch result {
        case .success(let regs): registers = regs
        case .failure(let message): errorMessage = message
        }
        isRunning = false
    }
}

struct ModbusTool: NetworkTool {
    let id = "modbus"
    let titleKey = L10n("tool.modbus.title")
    let subtitleKey = L10n("tool.modbus.subtitle")
    let systemImage = "gauge.with.dots.needle.bottom.50percent"
    let category: ToolCategory = .professional

    func makeView() -> AnyView { AnyView(ModbusView()) }
}

struct ModbusView: View {
    @Environment(\.theme) private var theme
    @Environment(SavedHostsStore.self) private var savedHosts
    @State private var viewModel = ModbusViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).font(AppTypography.footnote).foregroundStyle(theme.danger)
                }
                if !viewModel.registers.isEmpty {
                    resultSection
                }
                Text(L10n("modbus.note")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.modbus.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("modbus.input.title"), systemImage: "gauge.with.dots.needle.bottom.50percent") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("banner.input.host"), text: $viewModel.host)
                    .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                    .autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                SavedHostMenu(host: $viewModel.host)
            }
            HStack(spacing: Spacing.md) {
                field(L10n("modbus.port"), $viewModel.portText)
                field(L10n("modbus.unit"), $viewModel.unitText)
            }
            Picker(L10nString("modbus.function"), selection: $viewModel.function) {
                Text(L10n("modbus.holding")).tag(3)
                Text(L10n("modbus.input")).tag(4)
            }
            .pickerStyle(.segmented)
            HStack(spacing: Spacing.md) {
                field(L10n("modbus.address"), $viewModel.addressText)
                field(L10n("modbus.quantity"), $viewModel.quantityText)
            }
            Button {
                Task { await viewModel.run() }
            } label: {
                Label(L10nString("modbus.action.read"), systemImage: "arrow.down.circle").font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent).disabled(viewModel.isRunning)
            if viewModel.isRunning { ProgressView() }
        }
    }

    private var resultSection: some View {
        SectionCard(title: L10n("modbus.section.registers"), systemImage: "list.number") {
            ForEach(Array(viewModel.registers.enumerated()), id: \.offset) { index, value in
                HStack {
                    Text("\((UInt16(viewModel.addressText) ?? 0) &+ UInt16(index))")
                        .font(AppTypography.monoCaption).foregroundStyle(theme.textSecondary)
                        .frame(minWidth: 60, alignment: .leading).environment(\.layoutDirection, .leftToRight)
                    Spacer()
                    Text("\(value)").font(AppTypography.monoBody).foregroundStyle(theme.textPrimary)
                        .environment(\.layoutDirection, .leftToRight)
                    Text(String(format: "0x%04X", value)).font(AppTypography.monoCaption).foregroundStyle(theme.mono)
                        .frame(minWidth: 70, alignment: .trailing).environment(\.layoutDirection, .leftToRight)
                }
            }
        }
    }

    private func field(_ label: LocalizedStringResource, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                .keyboardType(.numberPad).environment(\.layoutDirection, .leftToRight)
        }
    }
}
