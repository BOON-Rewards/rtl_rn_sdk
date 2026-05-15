package com.affina.rtlsdk.reactnative

import com.affina.rtlsdk.RTLExperienceResult
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap

internal fun RTLExperienceResult.toWritableMap(): WritableMap {
    return Arguments.createMap().apply {
        putBoolean("success", success)
        putString("errorCode", errorCode)
    }
}
