import Foundation
import CryptoKit

/// Device metadata returned by ONVIF `GetDeviceInformation`.
struct ONVIFDeviceInfo: Sendable, Equatable {
    var manufacturer = ""
    var model = ""
    var firmware = ""
    var serial = ""

    var isEmpty: Bool { manufacturer.isEmpty && model.isEmpty && firmware.isEmpty }
}

/// One media profile plus the URIs resolved for it.
struct ONVIFProfile: Identifiable, Sendable, Equatable {
    let token: String
    var name: String
    var width: Int?
    var height: Int?
    var encoding: String?
    var streamURI: String?
    var snapshotURI: String?

    var id: String { token }

    var resolutionText: String? {
        guard let width, let height else { return nil }
        return "\(width)×\(height)"
    }
}

/// A PTZ preset position.
struct ONVIFPreset: Identifiable, Sendable, Equatable {
    let token: String
    var name: String
    var id: String { token }
}

/// The full result of interrogating a camera over ONVIF.
struct ONVIFDiscovery: Sendable, Equatable {
    var deviceInfo: ONVIFDeviceInfo
    var profiles: [ONVIFProfile]
    var ptzXAddr: String?
}

enum ONVIFError: LocalizedError {
    case network
    case noProfiles
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .network: return L10nString("onvif.error.network")
        case .noProfiles: return L10nString("onvif.error.noProfiles")
        case .unauthorized: return L10nString("onvif.error.unauthorized")
        }
    }
}

/// A dependency-free ONVIF client speaking SOAP 1.2 over `URLSession`.
///
/// Authentication uses the WS-UsernameToken **PasswordDigest** scheme
/// (`Base64(SHA1(nonce + created + password))`). `clockOffset` (seconds) is
/// added to the device's local clock when stamping `Created`, so callers can
/// align to the camera's clock (measured via `measureClockOffset()`) and avoid
/// skew rejections — important for the frequent PTZ commands.
struct ONVIFClient: Sendable {
    let host: String
    let port: UInt16
    let username: String
    let password: String
    var clockOffset: TimeInterval = 0

    private var deviceServiceURL: String { "http://\(host):\(port)/onvif/device_service" }

    private static let deviceNS = "http://www.onvif.org/ver10/device/wsdl"
    private static let mediaNS = "http://www.onvif.org/ver10/media/wsdl"
    private static let ptzNS = "http://www.onvif.org/ver20/ptz/wsdl"
    private static let schemaNS = "http://www.onvif.org/ver10/schema"

    // MARK: - Orchestration

    /// Interrogates the camera: device info, media service address, profiles and
    /// per-profile stream + snapshot URIs.
    func discover() async throws -> ONVIFDiscovery {
        var client = self
        client.clockOffset = await client.measureClockOffset()

        var deviceInfo = ONVIFDeviceInfo()
        if let info = try? await client.fetchDeviceInfo() { deviceInfo = info }

        let capabilities = try? await client.fetchCapabilities()
        let mediaXAddr = capabilities?.media ?? client.deviceServiceURL

        var profiles = try await client.fetchProfiles(at: mediaXAddr)
        guard !profiles.isEmpty else { throw ONVIFError.noProfiles }

        for index in profiles.indices {
            let token = profiles[index].token
            profiles[index].streamURI = try? await client.fetchStreamURI(profileToken: token, at: mediaXAddr)
            profiles[index].snapshotURI = try? await client.fetchSnapshotURI(profileToken: token, at: mediaXAddr)
        }

        return ONVIFDiscovery(deviceInfo: deviceInfo, profiles: profiles, ptzXAddr: capabilities?.ptz)
    }

    /// Returns (deviceUTC − now) in seconds, so `Created` can track the camera.
    func measureClockOffset() async -> TimeInterval {
        let body = "<GetSystemDateAndTime xmlns=\"\(Self.deviceNS)\"/>"
        guard let response = try? await send(to: deviceServiceURL, action: "\(Self.deviceNS)/GetSystemDateAndTime", body: body, authenticated: false) else {
            return 0
        }
        let parser = ONVIFTimeParser()
        parser.run(response)
        guard let stamp = parser.timestamp, let deviceDate = Self.parseTimestamp(stamp) else { return 0 }
        return deviceDate.timeIntervalSince(Date())
    }

    // MARK: - Media operations

    private func fetchDeviceInfo() async throws -> ONVIFDeviceInfo {
        let body = "<GetDeviceInformation xmlns=\"\(Self.deviceNS)\"/>"
        let response = try await send(to: deviceServiceURL, action: "\(Self.deviceNS)/GetDeviceInformation", body: body, authenticated: true)
        let fields = ONVIFStringParser(wanted: ["Manufacturer", "Model", "FirmwareVersion", "SerialNumber"])
        fields.run(response)
        return ONVIFDeviceInfo(
            manufacturer: fields.values["Manufacturer"] ?? "",
            model: fields.values["Model"] ?? "",
            firmware: fields.values["FirmwareVersion"] ?? "",
            serial: fields.values["SerialNumber"] ?? ""
        )
    }

    private func fetchCapabilities() async throws -> (media: String?, ptz: String?) {
        let body = "<GetCapabilities xmlns=\"\(Self.deviceNS)\"><Category>All</Category></GetCapabilities>"
        let response = try await send(to: deviceServiceURL, action: "\(Self.deviceNS)/GetCapabilities", body: body, authenticated: true)
        let parser = ONVIFCapabilitiesParser()
        parser.run(response)
        return (parser.mediaXAddr, parser.ptzXAddr)
    }

    private func fetchProfiles(at url: String) async throws -> [ONVIFProfile] {
        let body = "<GetProfiles xmlns=\"\(Self.mediaNS)\"/>"
        let response = try await send(to: url, action: "\(Self.mediaNS)/GetProfiles", body: body, authenticated: true)
        let parser = ONVIFProfilesParser()
        parser.run(response)
        return parser.profiles
    }

    private func fetchStreamURI(profileToken: String, at url: String) async throws -> String? {
        let body = """
        <GetStreamUri xmlns="\(Self.mediaNS)">\
        <StreamSetup><Stream xmlns="\(Self.schemaNS)">RTP-Unicast</Stream>\
        <Transport xmlns="\(Self.schemaNS)"><Protocol>RTSP</Protocol></Transport></StreamSetup>\
        <ProfileToken>\(profileToken)</ProfileToken></GetStreamUri>
        """
        let response = try await send(to: url, action: "\(Self.mediaNS)/GetStreamUri", body: body, authenticated: true)
        let fields = ONVIFStringParser(wanted: ["Uri"])
        fields.run(response)
        return fields.values["Uri"]
    }

    private func fetchSnapshotURI(profileToken: String, at url: String) async throws -> String? {
        let body = "<GetSnapshotUri xmlns=\"\(Self.mediaNS)\"><ProfileToken>\(profileToken)</ProfileToken></GetSnapshotUri>"
        let response = try await send(to: url, action: "\(Self.mediaNS)/GetSnapshotUri", body: body, authenticated: true)
        let fields = ONVIFStringParser(wanted: ["Uri"])
        fields.run(response)
        return fields.values["Uri"]
    }

    // MARK: - PTZ operations

    /// Starts a continuous pan/tilt/zoom move. Velocities are in [-1, 1].
    func continuousMove(profileToken: String, ptzXAddr: String, pan: Double, tilt: Double, zoom: Double) async throws {
        let body = """
        <ContinuousMove xmlns="\(Self.ptzNS)"><ProfileToken>\(profileToken)</ProfileToken>\
        <Velocity><PanTilt x="\(Self.format(pan))" y="\(Self.format(tilt))" xmlns="\(Self.schemaNS)"/>\
        <Zoom x="\(Self.format(zoom))" xmlns="\(Self.schemaNS)"/></Velocity></ContinuousMove>
        """
        _ = try await send(to: ptzXAddr, action: "\(Self.ptzNS)/ContinuousMove", body: body, authenticated: true)
    }

    func stopMove(profileToken: String, ptzXAddr: String) async throws {
        let body = "<Stop xmlns=\"\(Self.ptzNS)\"><ProfileToken>\(profileToken)</ProfileToken><PanTilt>true</PanTilt><Zoom>true</Zoom></Stop>"
        _ = try await send(to: ptzXAddr, action: "\(Self.ptzNS)/Stop", body: body, authenticated: true)
    }

    func getPresets(profileToken: String, ptzXAddr: String) async throws -> [ONVIFPreset] {
        let body = "<GetPresets xmlns=\"\(Self.ptzNS)\"><ProfileToken>\(profileToken)</ProfileToken></GetPresets>"
        let response = try await send(to: ptzXAddr, action: "\(Self.ptzNS)/GetPresets", body: body, authenticated: true)
        let parser = ONVIFPresetsParser()
        parser.run(response)
        return parser.presets
    }

    func gotoPreset(profileToken: String, ptzXAddr: String, presetToken: String) async throws {
        let body = "<GotoPreset xmlns=\"\(Self.ptzNS)\"><ProfileToken>\(profileToken)</ProfileToken><PresetToken>\(presetToken)</PresetToken></GotoPreset>"
        _ = try await send(to: ptzXAddr, action: "\(Self.ptzNS)/GotoPreset", body: body, authenticated: true)
    }

    // MARK: - Transport

    private func send(to urlString: String, action: String, body: String, authenticated: Bool) async throws -> String {
        guard let url = URL(string: urlString) else { throw ONVIFError.network }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/soap+xml; charset=utf-8; action=\"\(action)\"", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(envelope(body: body, authenticated: authenticated).utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let text = String(decoding: data, as: UTF8.self)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 { throw ONVIFError.unauthorized }
            if http.statusCode >= 400 {
                if text.localizedCaseInsensitiveContains("NotAuthorized") { throw ONVIFError.unauthorized }
                throw ONVIFError.network
            }
        }
        return text
    }

    private func envelope(body: String, authenticated: Bool) -> String {
        let header = authenticated ? securityHeader() : ""
        return """
        <?xml version="1.0" encoding="UTF-8"?>\
        <s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">\
        \(header)<s:Body>\(body)</s:Body></s:Envelope>
        """
    }

    private func securityHeader() -> String {
        let created = createdTimestamp()
        let nonceData = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        var digestInput = nonceData
        digestInput.append(Data(created.utf8))
        digestInput.append(Data(password.utf8))
        let digest = Data(Insecure.SHA1.hash(data: digestInput)).base64EncodedString()
        let nonce = nonceData.base64EncodedString()
        let wsse = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
        let wsu = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
        let digestType = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest"
        let encoding = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary"
        return """
        <s:Header><Security s:mustUnderstand="1" xmlns="\(wsse)">\
        <UsernameToken><Username>\(Self.escape(username))</Username>\
        <Password Type="\(digestType)">\(digest)</Password>\
        <Nonce EncodingType="\(encoding)">\(nonce)</Nonce>\
        <Created xmlns="\(wsu)">\(created)</Created>\
        </UsernameToken></Security></s:Header>
        """
    }

    // MARK: - Helpers

    private func createdTimestamp() -> String {
        var calendar = Calendar(identifier: .gregorian)
        if let utc = TimeZone(identifier: "UTC") { calendar.timeZone = utc }
        let date = Date().addingTimeInterval(clockOffset)
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(format: "%04d-%02d-%02dT%02d:%02d:%02d.000Z",
                      c.year ?? 1970, c.month ?? 1, c.day ?? 1, c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
    }

    private static func parseTimestamp(_ stamp: String) -> Date? {
        let cleaned = stamp.replacingOccurrences(of: "Z", with: "")
        let dateTime = cleaned.split(separator: "T")
        guard dateTime.count == 2 else { return nil }
        let dateParts = dateTime[0].split(separator: "-")
        let timeCore = dateTime[1].split(separator: ".").first ?? dateTime[1]
        let timeParts = timeCore.split(separator: ":")
        guard dateParts.count == 3, timeParts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = Int(dateParts[0]); components.month = Int(dateParts[1]); components.day = Int(dateParts[2])
        components.hour = Int(timeParts[0]); components.minute = Int(timeParts[1]); components.second = Int(timeParts[2])
        var calendar = Calendar(identifier: .gregorian)
        if let utc = TimeZone(identifier: "UTC") { calendar.timeZone = utc }
        return calendar.date(from: components)
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
