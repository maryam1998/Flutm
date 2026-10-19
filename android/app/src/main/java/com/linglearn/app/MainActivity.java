package com.linglearn.app;

import androidx.annotation.NonNull;

import com.linglearn.app.overlay.LinglearnBridge;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;

public class MainActivity extends FlutterActivity {
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        flutterEngine.getPlugins().add(new LinglearnBridge());
    }
}
