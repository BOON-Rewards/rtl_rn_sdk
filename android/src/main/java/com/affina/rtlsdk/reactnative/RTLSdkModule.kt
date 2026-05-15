package com.affina.rtlsdk.reactnative

import android.app.Activity
import com.affina.rtlsdk.RTLEnvironment
import com.affina.rtlsdk.RTLSdkPermissionRequester
import com.affina.rtlsdk.RTLSdk
import com.affina.rtlsdk.RTLSdkListener
import com.affina.rtlsdk.RTLStore
import com.affina.rtlsdk.location.RTLLocationModule
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.facebook.react.modules.core.PermissionAwareActivity
import com.facebook.react.modules.core.PermissionListener
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

class RTLSdkModule(
    private val reactContext: ReactApplicationContext
) : ReactContextBaseJavaModule(reactContext), RTLSdkListener {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val tokenRequests = ConcurrentHashMap<String, CompletableDeferred<String?>>()
    private val permissionRequester = RTLSdkPermissionRequester { activity, permissions, requestCode ->
        requestPermissions(activity, permissions, requestCode)
    }

    init {
        RTLSdk.getInstance().permissionRequester = permissionRequester
    }

    override fun getName(): String = NAME

    override fun invalidate() {
        if (RTLSdk.getInstance().permissionRequester === permissionRequester) {
            RTLSdk.getInstance().permissionRequester = null
        }
        tokenRequests.values.forEach { deferred ->
            deferred.complete(null)
        }
        tokenRequests.clear()
        scope.cancel()
        super.invalidate()
    }

    @ReactMethod
    fun initialize(options: ReadableMap, promise: Promise) {
        val activity = currentActivity
        if (activity == null) {
            promise.reject("activity_unavailable", "Cannot initialize RTL SDK without a current Activity")
            return
        }

        val program = options.getString("program")
        val environment = options.getString("environment")
        val urlScheme = options.getString("urlScheme")
        val externalChapterId = options.getNullableString("externalChapterId")

        if (program.isNullOrBlank() || environment.isNullOrBlank() || urlScheme.isNullOrBlank()) {
            promise.reject("invalid_options", "program, environment, and urlScheme are required")
            return
        }

        val rtlEnvironment = when (environment.lowercase()) {
            "staging" -> RTLEnvironment.STAGING
            "production" -> RTLEnvironment.PRODUCTION
            else -> {
                promise.reject("invalid_environment", "environment must be staging or production")
                return
            }
        }

        try {
            RTLSdk.getInstance().initialize(
                program = program,
                environment = rtlEnvironment,
                urlScheme = urlScheme,
                context = activity,
                listener = this,
                externalChapterId = externalChapterId
            )
            RTLLocationModule.install(RTLSdk.getInstance())
            promise.resolve(null)
        } catch (error: Throwable) {
            promise.reject("initialize_failed", error)
        }
    }

    @ReactMethod
    fun presentExperience(options: ReadableMap?, promise: Promise) {
        scope.launch {
            try {
                val result = RTLSdk.getInstance().presentExperience(
                    rtlEventId = options?.getNullableString("rtlEventId"),
                    rtlRedirectUrl = options?.getNullableString("rtlRedirectUrl")
                )
                promise.resolve(result.toWritableMap())
            } catch (error: Throwable) {
                promise.reject("present_experience_failed", error)
            }
        }
    }

    @ReactMethod
    fun login(token: String, options: ReadableMap?, promise: Promise) {
        scope.launch {
            try {
                val result = RTLSdk.getInstance().login(
                    token = token,
                    rtlEventId = options?.getNullableString("rtlEventId"),
                    rtlRedirectUrl = options?.getNullableString("rtlRedirectUrl")
                )
                promise.resolve(result.toWritableMap())
            } catch (error: Throwable) {
                promise.reject("login_failed", error)
            }
        }
    }

    @ReactMethod
    fun logout() {
        RTLSdk.getInstance().logout()
    }

    @ReactMethod
    fun enableLocationFeatures(promise: Promise) {
        val activity = currentActivity
        if (activity == null) {
            promise.reject("activity_unavailable", "Cannot enable location features without a current Activity")
            return
        }

        try {
            RTLSdk.getInstance().enableLocationFeatures(activity)
            promise.resolve(null)
        } catch (error: Throwable) {
            promise.reject("enable_location_failed", error)
        }
    }

    @ReactMethod
    fun disableLocationFeatures() {
        RTLSdk.getInstance().disableLocationFeatures()
    }

    @ReactMethod
    fun isLoggedIn(promise: Promise) {
        promise.resolve(RTLSdk.getInstance().isLoggedIn())
    }

    @ReactMethod
    fun hasLocationPermission(promise: Promise) {
        promise.resolve(RTLSdk.getInstance().hasLocationPermission)
    }

    @ReactMethod
    fun provideToken(requestId: String, token: String?) {
        tokenRequests.remove(requestId)?.complete(token)
    }

    @ReactMethod
    fun addListener(eventName: String) {
        // Required by NativeEventEmitter.
    }

    @ReactMethod
    fun removeListeners(count: Int) {
        // Required by NativeEventEmitter.
    }

    override suspend fun onNeedsToken(): String? {
        val requestId = UUID.randomUUID().toString()
        val deferred = CompletableDeferred<String?>()
        tokenRequests[requestId] = deferred

        val payload = Arguments.createMap().apply {
            putString("requestId", requestId)
        }
        sendEvent("onNeedsToken", payload)

        return withTimeoutOrNull(TOKEN_REQUEST_TIMEOUT_MS) {
            deferred.await()
        }.also {
            tokenRequests.remove(requestId)
        }
    }

    override fun onAuthenticated(accessToken: String, refreshToken: String) {
        val payload = Arguments.createMap().apply {
            putString("accessToken", accessToken)
            putString("refreshToken", refreshToken)
        }
        sendEvent("onAuthenticated", payload)
    }

    override fun onLogout() {
        sendEvent("onLogout", null)
    }

    override fun onOpenUrl(url: String, forceExternal: Boolean) {
        val payload = Arguments.createMap().apply {
            putString("url", url)
            putBoolean("forceExternal", forceExternal)
        }
        sendEvent("onOpenUrl", payload)
    }

    override fun onReady() {
        sendEvent("onReady", null)
    }

    override val onLocationPermissionChange: ((granted: Boolean) -> Unit)? = { granted ->
        val payload = Arguments.createMap().apply {
            putBoolean("granted", granted)
        }
        sendEvent("onLocationPermissionChange", payload)
    }

    override val onGeofenceEnter: ((store: RTLStore) -> Unit)? = { store ->
        val storePayload = Arguments.createMap().apply {
            putString("id", store.id)
            putString("name", store.name)
            putString("merchantId", store.merchantId)
            putDouble("latitude", store.latitude)
            putDouble("longitude", store.longitude)
            putString("offerTitle", store.offerTitle)
            putString("offerDescription", store.offerDescription)
        }
        val payload = Arguments.createMap().apply {
            putMap("store", storePayload)
        }
        sendEvent("onGeofenceEnter", payload)
    }

    private fun sendEvent(eventName: String, payload: Any?) {
        if (!reactContext.hasActiveReactInstance()) return
        reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit(eventName, payload)
    }

    private fun requestPermissions(
        activity: Activity,
        permissions: Array<String>,
        requestCode: Int
    ) {
        val permissionAwareActivity = activity as? PermissionAwareActivity
            ?: currentActivity as? PermissionAwareActivity

        if (permissionAwareActivity == null) {
            activity.requestPermissions(permissions, requestCode)
            return
        }

        permissionAwareActivity.requestPermissions(
            permissions,
            requestCode,
            PermissionListener { resultRequestCode, resultPermissions, grantResults ->
                if (resultRequestCode != requestCode) {
                    return@PermissionListener false
                }

                RTLSdk.getInstance().handlePermissionResult(
                    resultRequestCode,
                    resultPermissions,
                    grantResults
                )
                true
            }
        )
    }

    companion object {
        const val NAME = "RTLSdk"
        private const val TOKEN_REQUEST_TIMEOUT_MS = 30_000L
    }
}
