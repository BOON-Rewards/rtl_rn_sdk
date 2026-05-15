import React
import RTLSdk
import UIKit

@objc(RTLViewManager)
final class RTLViewManager: RCTViewManager {
    override static func requiresMainQueueSetup() -> Bool {
        true
    }

    override func view() -> UIView! {
        let view = RTLSdk.shared.createWebView()
        view.isUserInteractionEnabled = true
        return view
    }
}
