import XCTest
import Testing
import CoreServices
@testable import MihomoMac

final class MihomoMacTests: XCTestCase {
    func testAppLaunches() {
        XCTAssertTrue(true)
    }
}

@Suite("Login Launch")
struct LoginLaunchTests {
    @Test("Recognizes a login item launch")
    func loginItemLaunch() {
        let event = makeLaunchEvent()
        event.setParam(NSAppleEventDescriptor(enumCode: keyAELaunchedAsLogInItem), forKeyword: keyAEPropData)

        #expect(AppDelegate.isLoginLaunch(event))
    }

    @Test("Does not treat a manual launch as a login item")
    func manualLaunch() {
        #expect(!AppDelegate.isLoginLaunch(makeLaunchEvent()))
    }

    @Test("Does not treat a missing event as a login item")
    func missingEvent() {
        #expect(!AppDelegate.isLoginLaunch(nil))
    }

    @Test("Does not treat a service item launch as a login item")
    func serviceItemLaunch() {
        let event = makeLaunchEvent()
        event.setParam(NSAppleEventDescriptor(enumCode: keyAELaunchedAsServiceItem), forKeyword: keyAEPropData)

        #expect(!AppDelegate.isLoginLaunch(event))
    }

    @Test("Does not treat a reopen event as an initial login launch")
    func reopenEvent() {
        let event = makeLaunchEvent(eventID: kAEReopenApplication)
        event.setParam(NSAppleEventDescriptor(enumCode: keyAELaunchedAsLogInItem), forKeyword: keyAEPropData)

        #expect(!AppDelegate.isLoginLaunch(event))
    }

    private func makeLaunchEvent(eventID: AEEventID = kAEOpenApplication) -> NSAppleEventDescriptor {
        NSAppleEventDescriptor(
            eventClass: kCoreEventClass,
            eventID: eventID,
            targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
    }
}
