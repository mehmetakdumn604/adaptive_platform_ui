import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../../style/sf_symbol.dart';
import '../adaptive_scaffold.dart';

/// iOS 26 styled tab bar with Liquid Glass effect
class IOS26TabBar extends StatelessWidget implements PreferredSizeWidget {
  const IOS26TabBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<AdaptiveNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Size get preferredSize => const Size.fromHeight(50);

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? CupertinoColors.black.withValues(alpha: 0.8)
            : CupertinoColors.white.withValues(alpha: 0.8),
        border: Border(
          top: BorderSide(
            color: isDark
                ? CupertinoColors.white.withValues(alpha: 0.1)
                : CupertinoColors.black.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
            height: 50,
            padding: const EdgeInsets.only(bottom: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                destinations.length,
                (index) => Expanded(
                  child: _TabBarItem(
                    destination: destinations[index],
                    isSelected: index == selectedIndex,
                    onTap: () => onTap(index),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabBarItem extends StatelessWidget {
  const _TabBarItem({required this.destination, required this.isSelected, required this.onTap});

  final AdaptiveNavigationDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;

    final iconColor = isSelected
        ? CupertinoColors.activeBlue
        : (isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2);

    final textColor = isSelected
        ? CupertinoColors.activeBlue
        : (isDark ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildIconWidget(iconColor),
          const SizedBox(height: 2),
          Text(
            destination.label,
            style: TextStyle(
              fontSize: 10,
              color: textColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// Build icon widget based on icon type
  Widget _buildIconWidget(Color iconColor) {
    final icon = isSelected && destination.selectedIcon != null
        ? destination.selectedIcon
        : destination.icon;

    // If icon is a PlatformIcon, render it as a widget
    if (icon is PlatformIcon) {
      return SizedBox(
        width: 24,
        height: 24,
        child: Center(child: _renderPlatformIcon(icon, iconColor)),
      );
    }

    // Otherwise, convert to IconData and render as Icon
    return Icon(_iconToIconData(icon), color: iconColor, size: 24);
  }

  /// Render PlatformIcon as appropriate widget
  Widget _renderPlatformIcon(PlatformIcon icon, Color iconColor) {
    // For now, we'll use a simple approach:
    // Return an Icon widget for SFSymbolIcon (since we have the mapping)
    // For AssetIcon and SvgIcon, we could return Image.asset or custom widget
    // But for tab bars, native rendering is handled elsewhere

    if (icon is SFSymbolIcon) {
      return Icon(
        _sfSymbolToCupertinoIcon(icon.name),
        color: icon.color ?? iconColor,
        size: icon.size,
      );
    } else if (icon is AssetIcon) {
      // Render PNG/JPEG asset
      return Image.asset(
        icon.assetPath,
        width: icon.size,
        height: icon.size,
        color: icon.color ?? iconColor,
        colorBlendMode: icon.color != null ? BlendMode.srcIn : null,
        errorBuilder: (context, error, stackTrace) {
          // Fallback if asset not found
          return Icon(CupertinoIcons.photo, color: iconColor, size: icon.size);
        },
      );
    } else if (icon is SvgIcon) {
      // For SVG, we'd need flutter_svg or similar package
      // For now, fallback to a placeholder
      // TODO: Add SVG rendering support with flutter_svg package
      return Icon(CupertinoIcons.photo, color: iconColor, size: icon.size);
    }

    // Fallback
    return Icon(CupertinoIcons.circle, color: iconColor, size: 24);
  }

  /// Convert various icon types to IconData for rendering
  IconData _iconToIconData(dynamic icon) {
    if (icon is IconData) {
      return icon;
    } else if (icon is String) {
      return _sfSymbolToCupertinoIcon(icon);
    } else if (icon is PlatformIcon) {
      // For PlatformIcon, return a placeholder IconData
      // The actual rendering will be handled by native tab bar or custom widget
      if (icon is SFSymbolIcon) {
        return _sfSymbolToCupertinoIcon(icon.name);
      }
      // For AssetIcon and SvgIcon, use a generic icon as placeholder
      return CupertinoIcons.photo;
    }
    return CupertinoIcons.circle;
  }

  IconData _sfSymbolToCupertinoIcon(String sfSymbol) {
    const iconMap = {
      'house': CupertinoIcons.house,
      'house.fill': CupertinoIcons.house_fill,
      'magnifyingglass': CupertinoIcons.search,
      'heart': CupertinoIcons.heart,
      'heart.fill': CupertinoIcons.heart_fill,
      'person': CupertinoIcons.person,
      'person.fill': CupertinoIcons.person_fill,
      'gear': CupertinoIcons.settings,
      'star': CupertinoIcons.star,
      'star.fill': CupertinoIcons.star_fill,
    };
    return iconMap[sfSymbol] ?? CupertinoIcons.circle;
  }
}
