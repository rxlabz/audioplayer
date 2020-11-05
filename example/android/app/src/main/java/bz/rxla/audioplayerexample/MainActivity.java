package com.chuongvd.audioplayerExample;

        import android.os.Bundle;
        import io.flutter.embedding.android.FlutterActivity;
        import io.flutter.embedding.engine.FlutterEngine;
        import io.flutter.plugins.GeneratedPluginRegistrant;
        import androidx.annotation.NonNull;


public class MainActivity extends FlutterActivity {
  @Override
  public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
    GeneratedPluginRegistrant.registerWith(flutterEngine);
  }
}
