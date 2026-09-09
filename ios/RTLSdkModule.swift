import Foundation
import React
import RTLSdk

@objc(RTLSdkModule)
final class RTLSdkModule: RCTEventEmitter, RTLSdkDelegate {
    private var hasListeners = false
    private var pendingAuthTokenContinuations: [String: CheckedContinuation<String?, Never>] = [:]

    override static func requiresMainQueueSetup() -> Bool {
        true
    }

    override func supportedEvents() -> [String]! {
        [
            "authTokenRequested",
            "onLoadingStateChanged",
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
        guard let baseUrlValue = options["baseUrl"] as? String, !baseUrlValue.isEmpty,
              let baseURL = URL(string: baseUrlValue),
              let scheme = baseURL.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              baseURL.host != nil,
              let urlScheme = options["urlScheme"] as? String, !urlScheme.isEmpty else {
            reject("invalid_options", "baseUrl must be a complete HTTP(S) URL and urlScheme is required", nil)
            return
        }

        let externalChapterId = options["externalChapterId"] as? String

        RTLSdk.shared.initialize(
            baseURL: baseURL,
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

    @objc(handleDeepLink:resolver:rejecter:)
    func handleDeepLink(
        _ urlValue: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: RCTPromiseRejectBlock
    ) {
        guard let url = URL(string: urlValue) else {
            resolve(false)
            return
        }
        Task { @MainActor in
            resolve(RTLSdk.shared.handleDeepLink(url))
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

    @objc(hasLocationPermission:rejecter:)
    func hasLocationPermission(
        _ resolve: RCTPromiseResolveBlock,
        rejecter reject: RCTPromiseRejectBlock
    ) {
        resolve(RTLSdk.shared.hasLocationPermission)
    }

    @objc(resolveAuthTokenRequest:token:)
    func resolveAuthTokenRequest(_ requestId: String, token: String?) {
        guard let continuation = pendingAuthTokenContinuations.removeValue(forKey: requestId) else {
            return
        }
        continuation.resume(returning: token)
    }

    func provideAuthToken() async -> String? {
        await withCheckedContinuation { continuation in
            let requestId = UUID().uuidString
            pendingAuthTokenContinuations[requestId] = continuation
            send("authTokenRequested", body: ["requestId": requestId])

            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                await MainActor.run {
                    guard let continuation = self?.pendingAuthTokenContinuations.removeValue(forKey: requestId) else {
                        return
                    }
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func onReady() {
        send("onReady", body: nil)
    }

    func onLoadingStateChanged(isLoading: Bool) {
        send("onLoadingStateChanged", body: ["isLoading": isLoading])
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
