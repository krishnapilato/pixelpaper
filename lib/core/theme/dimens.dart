import 'package:flutter/material.dart' show Durations, Easing;
import 'package:flutter/widgets.dart';

/// Spacing scale. Generous by design: the interface should breathe.
abstract final class Space {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Horizontal page margin used by every screen.
  static const double page = 20;

  /// Room left at the bottom of scrollables so content clears the nav bar.
  static const double bottomInset = 120;
}

/// Material 3 corner scale.
abstract final class Radii {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double full = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius sheet =
      BorderRadius.vertical(top: Radius.circular(xl));
}

/// Motion, on the Material 3 duration and easing tokens.
///
/// Short, confident, never showy: things that enter decelerate into place,
/// things that leave accelerate away, and anything that moves across the
/// screen uses the emphasized curve.
abstract final class Motion {
  /// Small components: icons, checkmarks, chips (M3 short3).
  static const Duration quick = Durations.short3;

  /// Most transitions: switches, fades, list entrances (M3 medium1).
  static const Duration base = Durations.medium1;

  /// Large surfaces and screen-level changes (M3 long1).
  static const Duration slow = Durations.long1;

  /// Page transitions of the Material motion system (M3 medium2).
  static const Duration transition = Durations.medium2;

  /// A surface growing into a full screen, such as the camera opening from
  /// its button (M3 long2).
  static const Duration expand = Durations.long2;

  /// Delay between consecutive items of a list entering together.
  static const Duration stagger = Duration(milliseconds: 28);

  static const Curve enter = Easing.emphasizedDecelerate;
  static const Curve exit = Easing.emphasizedAccelerate;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve standard = Easing.standard;
}
