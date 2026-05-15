import Foundation
import React
import RTLSdk

@objc(RTLSdkModule)
final class RTLSdkModule: RCTEventEmitter, RTLSdkDelegate {
    private var hasListeners = false
    private var pendingTokenContinuations: [String: CheckedContinuation<String?, Never>] = [:]

    override static func requiresMainQueueSetup() -> Bool {
        true
    }

    override func supportedEvents() -> [String]! {
        [
            "onNeedsToken",
            "onAuthenticated",
            "onLogout",
            "onOpenUrl",
            "onReady",
            "onLocationPermissionChange",
            "onGeofenceEnter"
        ]
    }

    override func startObserving() {
        hasListeners = true
    }

    override func stopObserving() {
        hasListeners = false
    }

    @objc(initialize:resolver:rejecter:)
    func initialize(
        _ options: NSDictionary,
        resolver resolve: RCTPromiseResolveBlock,
        rejecter reject: RCTPromiseRejectBlock
    ) {
        guard let program = options["program"] as? String, !program.isEmpty,
              let environmentValue = options["environment"] as? String, !environmentValue.isEmpty,
              let urlScheme = options["urlScheme"] as? String, !urlScheme.isEmpty else {
            reject("invalid_options", "program, environment, and urlScheme are required", nil)
            return
        }

        let environment: RTLEnvironment
        switch environmentValue.lowercased() {
        case "staging":
            environment = .staging
        case "production":
            environment = .production
        default:
            reject("invalid_environment", "environment must be staging or production", nil)
            return
        }

        let externalChapterId = options["externalChapterId"] as? String

        RTLSdk.shared.initialize(
            program: program,
            environment: environment,
            urlScheme: urlScheme,
            delegate: self,
            externalChapterId: externalChapterId
        )
        resolve(nil)
    }

    @objc(presentExperience:resolver:rejecter:)
    func presentExperience(
        _ options: NSDictionary?,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            let result = await RTLSdk.shared.presentExperience(
                rtlEventId: options?["rtlEventId"] as? String,
                rtlRedirectUrl: options?["rtlRedirectUrl"] as? String
            )
            resolve(result.toDictionary())
        }
    }

    @objc(login:options:resolver:rejecter:)
    func login(
        _ token: String,
        options: NSDictionary?,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            let result = await RTLSdk.shared.login(
                token: token,
                rtlEventId: options?["rtlEventId"] as? String,
                rtlRedirectUrl: options?["rtlRedirectUrl"] as? String
            )
            resolve(result.toDictionary())
        }
    }

    @objc(logout)
    func logout() {
        RTLSdk.shared.logout()
    }

    @objc(enableLocationFeatures:rejecter:)
    func enableLocationFeatures(
        _ resolve: RCTPromiseResolveBlock,
        rejecter reject: RCTPromiseRejectBlock
    ) {
        RTLSdk.shared.enableLocationFeatures()
        resolve(nil)
    }

    @objc(disableLocationFeatures)
    func disableLocationFeatures() {
        RTLSdk.shared.disableLocationFeatures()
    }

    @objc(isLoggedIn:rejecter:)
    func isLoggedIn(
        _ resolve: RCTPromiseResolveBlock,
        rejecter reject: RCTPromiseRejectBlock
    ) {
        if let isLoggedIn = RTLSdk.shared.isLoggedIn() {
            resolve(isLoggedIn)
        } else {
            resolve(NSNull())
        }
    }

    @objc(hasLocationPermission:rejecter:)
    func hasLocationPermission(
        _ resolve: RCTPromiseResolveBlock,
        rejecter reject: RCTPromiseRejectBlock
    ) {
        resolve(RTLSdk.shared.hasLocationPermission)
    }

    @objc(provideToken:token:)
    func provideToken(_ requestId: String, token: String?) {
        guard let continuation = pendingTokenContinuations.removeValue(forKey: requestId) else {
            return
        }
        continuation.resume(returning: token)
    }

    func onNeedsToken() async -> String? {
        await withCheckedContinuation { continuation in
            let requestId = UUID().uuidString
            pendingTokenContinuations[requestId] = continuation
            send("onNeedsToken", body: ["requestId": requestId])

            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                await MainActor.run {
                    guard let continuation = self?.pendingTokenContinuations.removeValue(forKey: requestId) else {
                        return
                    }
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func onAuthenticated(accessToken: String, refreshToken: String) {
        send("onAuthenticated", body: [
            "accessToken": accessToken,
            "refreshToken": refreshToken
        ])
    }

    func onLogout() {
        send("onLogout", body: nil)
    }

    func onOpenUrl(url: URL, forceExternal: Bool) {
        send("onOpenUrl", body: [
            "url": url.absoluteString,
            "forceExternal": forceExternal
        ])
    }

    func onReady() {
        send("onReady", body: nil)
    }

    func onLocationPermissionChange(granted: Bool) {
        send("onLocationPermissionChange", body: ["granted": granted])
    }

    func onGeofenceEnter(store: RTLStore) {
        send("onGeofenceEnter", body: [
            "store": store.toDictionary()
        ])
    }

    private func send(_ eventName: String, body: Any?) {
        guard hasListeners else { return }
        sendEvent(withName: eventName, body: body)
    }
}

private extension RTLExperienceResult {
    func toDictionary() -> [String: Any] {
        [
            "success": success,
            "errorCode": errorCode as Any
        ]
    }
}

private extension RTLStore {
    func toDictionary() -> [String: Any] {
        [
            "id": id,
            "name": name,
            "merchantId": merchantId,
            "latitude": latitude,
            "longitude": longitude,
            "offerTitle": offerTitle as Any,
            "offerDescription": offerDescription as Any
        ]
    }
}
