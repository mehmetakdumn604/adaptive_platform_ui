import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import '../../style/sf_symbol.dart';
import '../adaptive_scaffold.dart';

/// Native iOS 26 tab bar using UITabBar platform view
class IOS26NativeTabBar extends StatefulWidget {
  const IOS26NativeTabBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onTap,
    this.tint,
    this.unselectedItemTint,
    this.backgroundColor,
    this.height,
    this.minimizeBehavior = TabBarMinimizeBehavior.automatic,
  });

  final List<AdaptiveNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final Color? tint;
  final Color? unselectedItemTint;
  final Color? backgroundColor;
  final double? height;

  /// Tab bar minimize behavior (iOS 26+)
  /// Controls how the tab bar minimizes when scrolling
  final TabBarMinimizeBehavior minimizeBehavior;

  @override
  State<IOS26NativeTabBar> createState() => _IOS26NativeTabBarState();
}

class _IOS26NativeTabBarState extends State<IOS26NativeTabBar> {
  MethodChannel? _channel;
  int? _lastIndex;
  int? _lastTint;
  int? _lastUnselectedTint;
  int? _lastBg;
  bool? _lastIsDark;
  double? _intrinsicHeight;
  List<String>? _lastLabels;
  List<Map<String, dynamic>>? _lastIcons;
  List<int?>? _lastBadgeCounts;
  TabBarMinimizeBehavior? _lastMinimizeBehavior;

  bool get _isDark =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  Color? get _effectiveTint =>
      widget.tint ?? CupertinoTheme.of(context).primaryColor;

  @override
  void didUpdateWidget(covariant IOS26NativeTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPropsToNativeIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBrightnessIfNeeded();
    _syncPropsToNativeIfNeeded();
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  /// Convert icon to a map that native side can understand
  Map<String, dynamic> _iconToMap(dynamic icon) {
    if (icon is PlatformIcon) {
      if (icon is SFSymbolIcon) {
        return {
          'type': 'sfSymbol',
          'name': icon.name,
          'size': icon.size,
          if (icon.color != null) 'color': _colorToARGB(icon.color!),
        };
      } else if (icon is AssetIcon) {
        return {
          'type': 'asset',
          'path': icon.assetPath,
          'size': icon.size,
          if (icon.color != null) 'color': _colorToARGB(icon.color!),
        };
      } else if (icon is SvgIcon) {
        return {
          'type': 'svg',
          'path': icon.assetPath,
          'size': icon.size,
          if (icon.color != null) 'color': _colorToARGB(icon.color!),
        };
      }
    } else if (icon is String) {
      // Legacy: String is treated as SF Symbol name
      return {
        'type': 'sfSymbol',
        'name': icon,
        'size': 24.0,
      };
    }
    
    // Fallback: empty/invalid icon
    return {
      'type': 'sfSymbol',
      'name': 'circle',
      'size': 24.0,
    };
  }

  int _colorToARGB(Color color) {
    // Resolve CupertinoDynamicColor if needed
    Color resolvedColor = color;
    if (color is CupertinoDynamicColor) {
      // Resolve based on current brightness
      final brightness = MediaQuery.platformBrightnessOf(context);
      resolvedColor = brightness == Brightness.dark
          ? color.darkColor
          : color.color;
    }

    return ((resolvedColor.a * 255.0).round() & 0xff) << 24 |
        ((resolvedColor.r * 255.0).round() & 0xff) << 16 |
        ((resolvedColor.g * 255.0).round() & 0xff) << 8 |
        ((resolvedColor.b * 255.0).round() & 0xff);
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isIOS) {
      final labels = widget.destinations.map((e) => e.label).toList();
      
      // Convert icons to a format native side can understand
      final icons = widget.destinations.map((e) => _iconToMap(e.icon)).toList();

      final searchFlags = widget.destinations.map((e) => e.isSearch).toList();
      final badgeCounts = widget.destinations.map((e) => e.badgeCount).toList();
      final spacerFlags = widget.destinations
          .map((e) => e.addSpacerAfter)
          .toList();

      final creationParams = <String, dynamic>{
        'labels': labels,
        'icons': icons,
        'searchFlags': searchFlags,
        'badgeCounts': badgeCounts,
        'spacerFlags': spacerFlags,
        'selectedIndex': widget.selectedIndex,
        'isDark': _isDark,
        'minimizeBehavior': widget.minimizeBehavior.index,
        if (_effectiveTint != null) 'tint': _colorToARGB(_effectiveTint!),
        if (widget.unselectedItemTint != null)
          'unselectedItemTint': _colorToARGB(widget.unselectedItemTint!),
        if (widget.backgroundColor != null)
          'backgroundColor': _colorToARGB(widget.backgroundColor!),
      };

      final platformView = UiKitView(
        viewType: 'adaptive_platform_ui/ios26_tab_bar',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onCreated,
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
        },
      );

      final h = widget.height ?? _intrinsicHeight ?? 50.0;
      return SizedBox(height: h, child: platformView);
    }

    // Fallback for non-iOS
    return SizedBox(
      height: widget.height ?? 50,
      child: Container(
        color:
            widget.backgroundColor ??
            CupertinoColors.systemBackground.resolveFrom(context),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(
            widget.destinations.length,
            (index) => CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => widget.onTap(index),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.circle,
                    color: index == widget.selectedIndex
                        ? CupertinoColors.activeBlue
                        : CupertinoColors.systemGrey,
                  ),
                  Text(
                    widget.destinations[index].label,
                    style: TextStyle(
                      fontSize: 10,
                      color: index == widget.selectedIndex
                          ? CupertinoColors.activeBlue
                          : CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onCreated(int id) {
    final ch = MethodChannel('adaptive_platform_ui/ios26_tab_bar_$id');
    _channel = ch;
    ch.setMethodCallHandler(_onMethodCall);
    _lastIndex = widget.selectedIndex;
    _lastTint = _effectiveTint != null ? _colorToARGB(_effectiveTint!) : null;
    _lastUnselectedTint = widget.unselectedItemTint != null
        ? _colorToARGB(widget.unselectedItemTint!)
        : null;
    _lastBg = widget.backgroundColor != null
        ? _colorToARGB(widget.backgroundColor!)
        : null;
    _lastIsDark = _isDark;
    _lastMinimizeBehavior = widget.minimizeBehavior;
    _requestIntrinsicSize();
    _cacheItems();
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method == 'valueChanged') {
      final args = call.arguments as Map?;
      final idx = (args?['index'] as num?)?.toInt();
      if (idx != null) {
        widget.onTap(idx);
        _lastIndex = idx;
      }
    }
    return null;
  }

  Future<void> _syncPropsToNativeIfNeeded() async {
    final ch = _channel;
    if (ch == null) return;

    final idx = widget.selectedIndex;
    final tint = _effectiveTint != null ? _colorToARGB(_effectiveTint!) : null;
    final unselectedTint = widget.unselectedItemTint != null
        ? _colorToARGB(widget.unselectedItemTint!)
        : null;
    final bg = widget.backgroundColor != null
        ? _colorToARGB(widget.backgroundColor!)
        : null;

    if (_lastIndex != idx) {
      await ch.invokeMethod('setSelectedIndex', {'index': idx});
      _lastIndex = idx;
    }

    final style = <String, dynamic>{};
    if (_lastTint != tint && tint != null) {
      style['tint'] = tint;
      _lastTint = tint;
    }
    if (_lastUnselectedTint != unselectedTint && unselectedTint != null) {
      style['unselectedItemTint'] = unselectedTint;
      _lastUnselectedTint = unselectedTint;
    }
    if (_lastBg != bg && bg != null) {
      style['backgroundColor'] = bg;
      _lastBg = bg;
    }
    if (style.isNotEmpty) {
      await ch.invokeMethod('setStyle', style);
    }

    // Items update (for hot reload or dynamic changes)
    final labels = widget.destinations.map((e) => e.label).toList();
    final icons = widget.destinations.map((e) => _iconToMap(e.icon)).toList();
    final searchFlags = widget.destinations.map((e) => e.isSearch).toList();
    final badgeCounts = widget.destinations.map((e) => e.badgeCount).toList();

    // Check if items changed by comparing JSON representation
    final iconsChanged = _lastIcons == null || 
        _lastIcons!.length != icons.length ||
        !_iconsEqual(_lastIcons!, icons);
    
    if (_lastLabels?.join('|') != labels.join('|') || iconsChanged) {
      await ch.invokeMethod('setItems', {
        'labels': labels,
        'icons': icons,
        'searchFlags': searchFlags,
        'badgeCounts': badgeCounts,
        'selectedIndex': widget.selectedIndex,
      });
      _lastLabels = labels;
      _lastIcons = icons;
      _requestIntrinsicSize();
    }

    // Badge counts update
    final currentBadgeCounts = widget.destinations
        .map((e) => e.badgeCount)
        .toList();
    if (_lastBadgeCounts?.join('|') != currentBadgeCounts.join('|')) {
      await ch.invokeMethod('setBadgeCounts', {
        'badgeCounts': currentBadgeCounts,
      });
      _lastBadgeCounts = currentBadgeCounts;
    }

    // Minimize behavior update
    if (_lastMinimizeBehavior != widget.minimizeBehavior) {
      await ch.invokeMethod('setMinimizeBehavior', {
        'behavior': widget.minimizeBehavior.index,
      });
      _lastMinimizeBehavior = widget.minimizeBehavior;
    }
  }

  Future<void> _syncBrightnessIfNeeded() async {
    final ch = _channel;
    if (ch == null) return;
    final isDark = _isDark;
    if (_lastIsDark != isDark) {
      await ch.invokeMethod('setBrightness', {'isDark': isDark});
      _lastIsDark = isDark;
    }
  }

  void _cacheItems() {
    _lastLabels = widget.destinations.map((e) => e.label).toList();
    _lastIcons = widget.destinations.map((e) => _iconToMap(e.icon)).toList();
    _lastBadgeCounts = widget.destinations.map((e) => e.badgeCount).toList();
  }

  /// Compare two lists of icon maps for equality
  bool _iconsEqual(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final aMap = a[i];
      final bMap = b[i];
      if (aMap['type'] != bMap['type']) return false;
      if (aMap['name'] != bMap['name']) return false;
      if (aMap['path'] != bMap['path']) return false;
      if (aMap['size'] != bMap['size']) return false;
      if (aMap['color'] != bMap['color']) return false;
    }
    return true;
  }

  Future<void> _requestIntrinsicSize() async {
    if (widget.height != null) return;
    final ch = _channel;
    if (ch == null) return;
    try {
      final size = await ch.invokeMethod<Map>('getIntrinsicSize');
      final h = (size?['height'] as num?)?.toDouble();
      if (!mounted) return;
      setState(() {
        if (h != null && h > 0) _intrinsicHeight = h;
      });
    } catch (_) {}
  }
}
