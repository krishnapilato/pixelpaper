package com.afonsoraposo.camera;

import android.app.Activity;
import android.content.Context;
import android.graphics.ImageFormat;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CameraMetadata;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.media.CamcorderProfile;
import android.util.Range;
import android.util.Rational;
import android.util.Size;
import com.afonsoraposo.camera.Camera.ResolutionPreset;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Provides various utilities for camera. */
public final class CameraUtils {

  private CameraUtils() {}

  static Size computeBestPreviewSize(String cameraName, ResolutionPreset preset) {
    if (preset.ordinal() > ResolutionPreset.high.ordinal()) {
      preset = ResolutionPreset.high;
    }

    CamcorderProfile profile =
        getBestAvailableCamcorderProfileForResolutionPreset(cameraName, preset);
    return new Size(profile.videoFrameWidth, profile.videoFrameHeight);
  }

  static Size computeBestCaptureSize(StreamConfigurationMap streamConfigurationMap) {
    // For still image captures, we use the largest available size.
    return Collections.max(
        Arrays.asList(streamConfigurationMap.getOutputSizes(ImageFormat.JPEG)),
        new CompareSizesByArea());
  }

  public static List<Map<String, Object>> getAvailableCameras(Activity activity)
      throws CameraAccessException {
    CameraManager cameraManager = (CameraManager) activity.getSystemService(Context.CAMERA_SERVICE);
    String[] cameraNames = cameraManager.getCameraIdList();
    List<Map<String, Object>> cameras = new ArrayList<>();
    for (String cameraName : cameraNames) {
      HashMap<String, Object> details = new HashMap<>();
      CameraCharacteristics characteristics = cameraManager.getCameraCharacteristics(cameraName);
      details.put("name", cameraName);
      int sensorOrientation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION);
      details.put("sensorOrientation", sensorOrientation);

      int lensFacing = characteristics.get(CameraCharacteristics.LENS_FACING);
      switch (lensFacing) {
        case CameraMetadata.LENS_FACING_FRONT:
          details.put("lensFacing", "front");
          break;
        case CameraMetadata.LENS_FACING_BACK:
          details.put("lensFacing", "back");
          break;
        case CameraMetadata.LENS_FACING_EXTERNAL:
          details.put("lensFacing", "external");
          break;
      }
      putCapabilities(characteristics, details);
      cameras.add(details);
    }
    return cameras;
  }

  /**
   * PixelPaper patch: what each lens can actually do, so a UI can offer only the manual controls
   * that will have an effect, within the sensor's real limits. Every key is optional on the Dart
   * side.
   */
  private static void putCapabilities(
      CameraCharacteristics characteristics, Map<String, Object> details) {
    int[] capabilities =
        characteristics.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES);
    boolean manualSensor = false;
    if (capabilities != null) {
      for (int capability : capabilities) {
        if (capability == CameraMetadata.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_SENSOR) {
          manualSensor = true;
          break;
        }
      }
    }
    details.put("manualSensor", manualSensor);

    Range<Integer> iso = characteristics.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE);
    if (iso != null) {
      details.put("isoMin", iso.getLower());
      details.put("isoMax", iso.getUpper());
    }

    Range<Long> exposure =
        characteristics.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE);
    if (exposure != null) {
      details.put("exposureMinNs", exposure.getLower());
      details.put("exposureMaxNs", exposure.getUpper());
    }

    Float minFocus = characteristics.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE);
    details.put("minFocusDiopters", minFocus == null ? 0.0 : minFocus.doubleValue());

    Boolean flash = characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE);
    details.put("flash", flash != null && flash);

    Range<Integer> compensation =
        characteristics.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE);
    Rational step = characteristics.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_STEP);
    if (compensation != null && step != null && step.getDenominator() != 0) {
      details.put("aeCompensationMin", compensation.getLower());
      details.put("aeCompensationMax", compensation.getUpper());
      details.put("aeCompensationStep", step.doubleValue());
    }

    details.put("maxZoom", (double) maxZoom(characteristics));

    int[] awbModes = characteristics.get(CameraCharacteristics.CONTROL_AWB_AVAILABLE_MODES);
    List<Integer> awb = new ArrayList<>();
    if (awbModes != null) {
      for (int mode : awbModes) {
        awb.add(mode);
      }
    }
    details.put("awbModes", awb);
  }

  /** PixelPaper patch: the largest zoom the lens supports, 1 when it has none. */
  static float maxZoom(CameraCharacteristics characteristics) {
    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
      Range<Float> ratio = characteristics.get(CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE);
      if (ratio != null) {
        return Math.max(1f, ratio.getUpper());
      }
    }
    Float digital = characteristics.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM);
    return digital == null ? 1f : Math.max(1f, digital);
  }

  static CamcorderProfile getBestAvailableCamcorderProfileForResolutionPreset(
      String cameraName, ResolutionPreset preset) {
    int cameraId = Integer.parseInt(cameraName);
    switch (preset) {
        // All of these cases deliberately fall through to get the best available profile.
      case max:
        if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_HIGH)) {
          return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_HIGH);
        }
      case ultraHigh:
        if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_2160P)) {
          return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_2160P);
        }
      case veryHigh:
        if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_1080P)) {
          return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_1080P);
        }
      case high:
        if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_720P)) {
          return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_720P);
        }
      case medium:
        if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_480P)) {
          return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_480P);
        }
      case low:
        if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_QVGA)) {
          return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_QVGA);
        }
      default:
        if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_LOW)) {
          return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_LOW);
        } else {
          throw new IllegalArgumentException(
              "No capture session available for current capture session.");
        }
    }
  }

  private static class CompareSizesByArea implements Comparator<Size> {
    @Override
    public int compare(Size lhs, Size rhs) {
      // We cast here to ensure the multiplications won't overflow.
      return Long.signum(
          (long) lhs.getWidth() * lhs.getHeight() - (long) rhs.getWidth() * rhs.getHeight());
    }
  }
}
