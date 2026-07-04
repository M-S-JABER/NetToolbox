import Foundation

/// Captures the first text value for each wanted element local-name.
/// Used for `GetDeviceInformation` fields and `Uri` results.
final class ONVIFStringParser: NSObject, XMLParserDelegate {
    let wanted: Set<String>
    private(set) var values: [String: String] = [:]
    private var current: String?
    private var buffer = ""

    init(wanted: Set<String>) { self.wanted = wanted }

    func run(_ xml: String) {
        let parser = XMLParser(data: Data(xml.utf8))
        parser.shouldProcessNamespaces = true
        parser.delegate = self
        parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if wanted.contains(elementName) { current = elementName; buffer = "" }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if current != nil { buffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        guard current == elementName else { return }
        if values[elementName] == nil {
            let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { values[elementName] = trimmed }
        }
        current = nil
    }
}

/// Reads the camera's `UTCDateTime` into a WS-Security `Created` timestamp.
final class ONVIFTimeParser: NSObject, XMLParserDelegate {
    private var inUTC = false
    private var current: String?
    private var buffer = ""
    private var fields: [String: Int] = [:]

    var timestamp: String? {
        guard let year = fields["Year"], let month = fields["Month"], let day = fields["Day"] else { return nil }
        return String(format: "%04d-%02d-%02dT%02d:%02d:%02d.000Z",
                      year, month, day, fields["Hour"] ?? 0, fields["Minute"] ?? 0, fields["Second"] ?? 0)
    }

    func run(_ xml: String) {
        let parser = XMLParser(data: Data(xml.utf8))
        parser.shouldProcessNamespaces = true
        parser.delegate = self
        parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if elementName == "UTCDateTime" {
            inUTC = true
        } else if inUTC, ["Year", "Month", "Day", "Hour", "Minute", "Second"].contains(elementName) {
            current = elementName
            buffer = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if current != nil { buffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        if elementName == "UTCDateTime" {
            inUTC = false
            current = nil
        } else if current == elementName {
            fields[elementName] = Int(buffer.trimmingCharacters(in: .whitespacesAndNewlines))
            current = nil
        }
    }
}

/// Extracts the Media (and PTZ) service addresses from `GetCapabilities`.
final class ONVIFCapabilitiesParser: NSObject, XMLParserDelegate {
    private(set) var mediaXAddr: String?
    private(set) var ptzXAddr: String?
    private var inMedia = false
    private var inPTZ = false
    private var capturing = false
    private var buffer = ""

    func run(_ xml: String) {
        let parser = XMLParser(data: Data(xml.utf8))
        parser.shouldProcessNamespaces = true
        parser.delegate = self
        parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        switch elementName {
        case "Media": inMedia = true
        case "PTZ": inPTZ = true
        case "XAddr": capturing = true; buffer = ""
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturing { buffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        switch elementName {
        case "XAddr":
            let value = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if inMedia, mediaXAddr == nil, !value.isEmpty { mediaXAddr = value }
            else if inPTZ, ptzXAddr == nil, !value.isEmpty { ptzXAddr = value }
            capturing = false
        case "Media": inMedia = false
        case "PTZ": inPTZ = false
        default: break
        }
    }
}

/// Builds the media profile list from `GetProfiles`.
final class ONVIFProfilesParser: NSObject, XMLParserDelegate {
    private(set) var profiles: [ONVIFProfile] = []
    private var token: String?
    private var name = ""
    private var width: Int?
    private var height: Int?
    private var encoding: String?
    private var inResolution = false
    private var current: String?
    private var buffer = ""

    func run(_ xml: String) {
        let parser = XMLParser(data: Data(xml.utf8))
        parser.shouldProcessNamespaces = true
        parser.delegate = self
        parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        switch elementName {
        case "Profiles":
            token = attributes["token"]
            name = ""
            width = nil
            height = nil
            encoding = nil
        case "Resolution":
            inResolution = true
        case "Name", "Width", "Height", "Encoding":
            current = elementName
            buffer = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if current != nil { buffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        switch elementName {
        case "Profiles":
            if let token {
                profiles.append(ONVIFProfile(
                    token: token,
                    name: name.isEmpty ? token : name,
                    width: width, height: height, encoding: encoding,
                    streamURI: nil, snapshotURI: nil
                ))
            }
            token = nil
        case "Resolution":
            inResolution = false
        default:
            guard current == elementName else { return }
            let value = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            switch elementName {
            case "Name": if name.isEmpty { name = value }
            case "Width": if inResolution, width == nil { width = Int(value) }
            case "Height": if inResolution, height == nil { height = Int(value) }
            case "Encoding": if encoding == nil { encoding = value }
            default: break
            }
            current = nil
        }
    }
}
