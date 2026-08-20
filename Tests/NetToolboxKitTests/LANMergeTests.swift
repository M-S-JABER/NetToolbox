import XCTest
@testable import NetToolboxKit

final class LANMergeTests: XCTestCase {

    func testSweepAndBonjourMergeByIP() {
        let devices = LANMerge.devices(
            swept: [HostResult(ip: "192.168.1.10", rttMs: 4), HostResult(ip: "192.168.1.20", rttMs: 9)],
            bonjour: [LANMerge.BonjourHit(ip: "192.168.1.10", name: "printer", serviceLabel: "Printer")],
            reverseDNS: ["192.168.1.20": "nas.local"]
        )
        XCTAssertEqual(devices.count, 2)
        // Sorted by numeric IP.
        XCTAssertEqual(devices[0].ip, "192.168.1.10")
        XCTAssertEqual(devices[0].name, "printer")           // from Bonjour
        XCTAssertEqual(devices[0].services, ["Printer"])
        XCTAssertEqual(devices[0].rttMs, 4)
        XCTAssertEqual(devices[1].name, "nas.local")         // from reverse DNS
        XCTAssertNil(devices[1].services.first)
    }

    func testBonjourOnlyDeviceStillListed() {
        // A Bonjour host that never answered the sweep still appears.
        let devices = LANMerge.devices(
            swept: [],
            bonjour: [LANMerge.BonjourHit(ip: "192.168.1.50", name: "tv", serviceLabel: "AirPlay")],
            reverseDNS: [:]
        )
        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices[0].ip, "192.168.1.50")
        XCTAssertEqual(devices[0].services, ["AirPlay"])
        XCTAssertNil(devices[0].rttMs)
    }

    func testBonjourNameWinsOverReverseDNS() {
        let devices = LANMerge.devices(
            swept: [HostResult(ip: "10.0.0.5", rttMs: 2)],
            bonjour: [LANMerge.BonjourHit(ip: "10.0.0.5", name: "Studio Mac", serviceLabel: "SSH")],
            reverseDNS: ["10.0.0.5": "host-5.lan"]
        )
        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices[0].name, "Studio Mac")
    }

    func testMultipleServicesAccumulateWithoutDuplicates() {
        let devices = LANMerge.devices(
            swept: [],
            bonjour: [
                LANMerge.BonjourHit(ip: "192.168.0.2", name: "hub", serviceLabel: "Web service"),
                LANMerge.BonjourHit(ip: "192.168.0.2", name: "hub", serviceLabel: "SSH"),
                LANMerge.BonjourHit(ip: "192.168.0.2", name: "hub", serviceLabel: "SSH"),
            ],
            reverseDNS: [:]
        )
        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices[0].services, ["Web service", "SSH"])
    }
}
