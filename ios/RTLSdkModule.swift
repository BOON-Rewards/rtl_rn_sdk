import Foundation
import React
import RTLSdk

@objc(RTLSdkModule)
final class RTLSdkModule: RCTEventEmitter, RTLSdkDelegate {
    private var hasListeners = false
    private struct TokenRequest {
        let continuation: CheckedContinuation<String?, Never>
        let timeout: DispatchWorkItem
    }
    // Accessed only on the main queue, including async delegate callbacks.
    private var pendingAuthTokenRequests: [String: TokenRequest] = [:]

    override static func requiresMainQueueSetup() -> Bool {
        true
    }

    override var methodQueue: DispatchQueue! { DispatchQueue.main }

    override func invalidate() {
        // RN may invalidate modules off their method queue. The base emitter
        // calls stopObserving(), so its cleanup must run on main too.
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [self] in invalidate() }
            return
        }
        hasListeners = false
        cancelAuthTokenRequests()
        super.invalidate()
    }

    override func supportedEvents() -> [String]! {
        [
            "authTokenRequested",
            "onLoadingStateChanged",
            "onReady"
        ]
    }

    override func startObserving() {
        hasListeners = true
    }

    override func stopObserving() {
        hasListeners = false
        cancelAuthTokenRequests()
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

        cancelAuthTokenRequests()
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
        cancelAuthTokenRequests()
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
        dispatchPrecondition(condition: .onQueue(.main))
        guard let request = pendingAuthTokenRequests.removeValue(forKey: requestId) else { return }
        request.timeout.cancel()
        request.continuation.resume(returning: token)
    }

    private func cancelAuthTokenRequests() {
        dispatchPrecondition(condition: .onQueue(.main))
        for id in Array(pendingAuthTokenRequests.keys) {
            resolveAuthTokenRequest(id, token: nil)
        }
    }

    func provideAuthToken() async -> String? {
        await requestAuthToken()
    }

    @MainActor
    private func requestAuthToken() async -> String? {
        let requestId = UUID().uuidString
        let cancelRequest: @MainActor @Sendable () -> Void = { [weak self] in
            self?.resolveAuthTokenRequest(requestId, token: nil)
        }
        return await withTaskCancellationHandler {
            guard !Task.isCancelled, hasListeners else { return nil }
            return await withCheckedContinuation { continuation in
                let timeout = DispatchWorkItem { [weak self] in
                    self?.resolveAuthTokenRequest(requestId, token: nil)
                }
                pendingAuthTokenRequests[requestId] = TokenRequest(
                    continuation: continuation, timeout: timeout
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timeout)
                send("authTokenRequested", body: ["requestId": requestId])
            }
        } onCancel: {
            Task { @MainActor in cancelRequest() }
        }
    }

    func onReady() {
        send("onReady", body: nil)
    }

    func onLoadingStateChanged(isLoading: Bool) {
        send("onLoadingStateChanged", body: ["isLoading": isLoading])
    }

    private func send(_ eventName: String, body: Any?) {
        let emit = { [self] in
            guard hasListeners else { return }
            sendEvent(withName: eventName, body: body)
        }
        if Thread.isMainThread { emit() }
        else { DispatchQueue.main.async(execute: emit) }
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
