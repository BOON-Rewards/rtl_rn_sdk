package com.affinaloyalty.rtlsdk.reactnative

import android.view.ViewGroup
import android.widget.FrameLayout
import com.affinaloyalty.rtlsdk.RTLSdk
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext

class RTLViewManager : SimpleViewManager<FrameLayout>() {
    override fun getName(): String = NAME

    override fun createViewInstance(reactContext: ThemedReactContext): FrameLayout {
        return FrameLayout(reactContext).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )

            val webViewContext = reactContext.currentActivity ?: reactContext
            val webView = RTLSdk.getInstance().createWebView(webViewContext)
            addView(
                webView,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
                )
            )
        }
    }

    companion object {
        const val NAME = "RTLView"
    }
}
