package com.example.survexus

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode

class MainActivity : FlutterActivity() {

    override fun getRenderMode(): RenderMode {
        return RenderMode.texture   // Prevent black screen / smooth startup
    }

    override fun getTransparencyMode(): TransparencyMode {
        return TransparencyMode.opaque
    }
}
