// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.afonsoraposo.camera;

import android.app.Activity;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import com.afonsoraposo.camera.CameraPermissions.PermissionsRegistry;
import io.flutter.view.TextureRegistry;

/**
 * Platform implementation of the camera_plugin.
 *
 * <p>PixelPaper patch: the v1 embedding entry point ({@code registerWith(Registrar)}) is gone,
 * because Flutter removed {@code PluginRegistry.Registrar}; the texture registry now comes from
 * the plugin binding instead of the deprecated {@code getFlutterEngine().getRenderer()}.
 */
public final class CameraPlugin implements FlutterPlugin, ActivityAware {

  private @Nullable FlutterPluginBinding flutterPluginBinding;
  private @Nullable MethodCallHandlerImpl methodCallHandler;

  public CameraPlugin() {}

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    this.flutterPluginBinding = binding;
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    this.flutterPluginBinding = null;
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    if (flutterPluginBinding == null) {
      return;
    }
    maybeStartListening(
        binding.getActivity(),
        flutterPluginBinding.getBinaryMessenger(),
        binding::addRequestPermissionsResultListener,
        flutterPluginBinding.getTextureRegistry());
  }

  @Override
  public void onDetachedFromActivity() {
    if (methodCallHandler == null) {
      return;
    }

    methodCallHandler.stopListening();
    methodCallHandler = null;
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    onAttachedToActivity(binding);
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity();
  }

  private void maybeStartListening(
      Activity activity,
      BinaryMessenger messenger,
      PermissionsRegistry permissionsRegistry,
      TextureRegistry textureRegistry) {
    methodCallHandler =
        new MethodCallHandlerImpl(
            activity, messenger, new CameraPermissions(), permissionsRegistry, textureRegistry);
  }
}
