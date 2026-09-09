package com.affinaloyalty.rtlsdk.reactnative

import android.view.ViewGroup
import android.widget.FrameLayout
import com.affinaloyalty.rtlsdk.RTLSdk
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext

class RTLViewManager : SimpleViewManager<FrameLayout>() {
    override fun getName(): String = NAME

    override fun createViewInstance(reactContext: ThemedReactContext): FrameLayout {
        return RTLViewContainer(reactContext).apply {
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

private class RTLViewContainer(context: ThemedReactContext) : FrameLayout(context) {
    private val layoutChildren = Runnable {
        if (!isAttachedToWindow) return@Runnable
        measure(
            MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY)
        )
        layout(left, top, right, bottom)
    }

    override fun requestLayout() {
        super.requestLayout()
        // React Native stops Android layout requests at its parent. The SDK
        // replaces its inner WebView during authentication, so lay out that
        // native subtree again using the bounds assigned by React Native.
        removeCallbacks(layoutChildren)
        post(layoutChildren)
    }

    override fun onDetachedFromWindow() {
        removeCallbacks(layoutChildren)
        super.onDetachedFromWindow()
    }
}
