package com.anathanwang.andexevents

import android.content.pm.PackageManager
import android.os.Bundle
import com.yandex.mapkit.MapKitFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    // Read API key from AndroidManifest metadata injected via Gradle placeholder.
    val appInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
    val apiKey = appInfo.metaData?.getString("com.yandex.maps.apikey")
    if (!apiKey.isNullOrBlank()) {
      MapKitFactory.setApiKey(apiKey)
    }

    MapKitFactory.initialize(this)
    super.onCreate(savedInstanceState)
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
  }
}
