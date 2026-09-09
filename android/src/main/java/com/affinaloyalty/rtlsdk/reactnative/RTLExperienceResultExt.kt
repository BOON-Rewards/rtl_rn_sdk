package com.affinaloyalty.rtlsdk.reactnative

import com.affinaloyalty.rtlsdk.RTLExperienceResult
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap

internal fun RTLExperienceResult.toWritableMap(): WritableMap {
    return Arguments.createMap().apply {
        putBoolean("success", success)
        putString("errorCode", errorCode)
    }
}
