package com.affinaloyalty.rtlsdk.reactnative

import com.facebook.react.bridge.ReadableMap

internal fun ReadableMap.getNullableString(key: String): String? {
    return if (hasKey(key) && !isNull(key)) getString(key) else null
}
