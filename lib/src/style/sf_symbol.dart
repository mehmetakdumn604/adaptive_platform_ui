import 'package:flutter/cupertino.dart';

/// Describes an SF Symbol for native iOS 26 rendering
///
/// SF Symbols are Apple's system icons that can be used in iOS apps.
/// For a full list of available symbols, see: https://developer.apple.com/sf-symbols/
///
/// Example:
/// ```dart
/// SFSymbol('star.fill', size: 24, color: Colors.blue)
/// ```
class SFSymbol {
  /// The SF Symbol name (e.g., 'star.fill', 'heart', 'plus.circle')
  final String name;

  /// The size of the symbol in points
  final double size;

  /// The color of the symbol
  final Color? color;

  /// Creates an SF Symbol descriptor for native iOS rendering
  const SFSymbol(this.name, {this.size = 24.0, this.color});

  /// Converts this SFSymbol to a PlatformIcon for use with the new icon system
  PlatformIcon toPlatformIcon() => SFSymbolIcon(name, size: size, color: color);
}

/// A sealed class representing different types of icons that can be used
/// in native iOS 26 rendering.
///
/// This class supports:
/// - SF Symbols (Apple's system icons)
/// - Asset images (PNG, JPEG, etc.)
/// - SVG images
///
/// Example:
/// ```dart
/// // SF Symbol
/// PlatformIcon.sfSymbol('star.fill', size: 24, color: Colors.blue)
///
/// // Asset image
/// PlatformIcon.asset('assets/icons/custom_icon.png', size: 24, color: Colors.blue)
///
/// // SVG image
/// PlatformIcon.svg('assets/icons/custom_icon.svg', size: 24, color: Colors.blue)
/// ```
sealed class PlatformIcon {
  /// The size of the icon in points
  final double size;

  /// The color of the icon (applied as tint for asset/SVG icons)
  final Color? color;

  /// Creates a PlatformIcon with the given size and color
  const PlatformIcon({this.size = 24.0, this.color});

  /// Creates an SF Symbol icon
  const factory PlatformIcon.sfSymbol(String name, {double size, Color? color}) = SFSymbolIcon;

  /// Creates an asset image icon (PNG, JPEG, etc.)
  ///
  /// The [assetPath] should be a path relative to the assets folder,
  /// e.g., 'assets/icons/custom_icon.png'
  const factory PlatformIcon.asset(String assetPath, {double size, Color? color}) = AssetIcon;

  /// Creates an SVG image icon
  ///
  /// The [assetPath] should be a path relative to the assets folder,
  /// e.g., 'assets/icons/custom_icon.svg'
  ///
  /// Note: SVG support on iOS uses SVGKit library to render SVG files as UIImage.
  /// The SVG will be rendered at the specified size with high quality.
  const factory PlatformIcon.svg(String assetPath, {double size, Color? color}) = SvgIcon;
}

/// An SF Symbol icon for native iOS rendering
class SFSymbolIcon extends PlatformIcon {
  /// The SF Symbol name (e.g., 'star.fill', 'heart', 'plus.circle')
  final String name;

  /// Creates an SF Symbol icon
  const SFSymbolIcon(this.name, {super.size = 24.0, super.color});
}

/// An asset image icon (PNG, JPEG, etc.) for native iOS rendering
class AssetIcon extends PlatformIcon {
  /// The asset path relative to the assets folder
  /// e.g., 'assets/icons/custom_icon.png'
  final String assetPath;

  /// Creates an asset image icon
  const AssetIcon(this.assetPath, {super.size = 24.0, super.color});
}

/// An SVG image icon for native iOS rendering
///
/// Note: SVG support on iOS requires the image to be rendered as a UIImage.
/// For best results, consider using PNG assets with @2x and @3x variants.
class SvgIcon extends PlatformIcon {
  /// The asset path relative to the assets folder
  /// e.g., 'assets/icons/custom_icon.svg'
  final String assetPath;

  /// Creates an SVG image icon
  const SvgIcon(this.assetPath, {super.size = 24.0, super.color});
}
