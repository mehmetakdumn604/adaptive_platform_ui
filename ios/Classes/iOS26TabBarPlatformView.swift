import Flutter
import UIKit
#if canImport(SVGKit)
import SVGKit
#endif

class iOS26TabBarPlatformView: NSObject, FlutterPlatformView, UITabBarDelegate {
    private let channel: FlutterMethodChannel
    private let container: UIView
    private var tabBar: UITabBar?
    private var minimizeBehavior: Int = 3 // automatic
    private var currentLabels: [String] = []
    private var currentIcons: [[String: Any]] = []
    private var currentSearchFlags: [Bool] = []
    private var currentBadgeCounts: [Int?] = []
    private var registrar: FlutterPluginRegistrar?

    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger, registrar: FlutterPluginRegistrar?) {
        self.registrar = registrar
        self.channel = FlutterMethodChannel(
            name: "adaptive_platform_ui/ios26_tab_bar_\(viewId)",
            binaryMessenger: messenger
        )
        self.container = UIView(frame: frame)

        var labels: [String] = []
        var icons: [[String: Any]] = []
        var searchFlags: [Bool] = []
        var badgeCounts: [Int?] = []
        var spacerFlags: [Bool] = []
        var selectedIndex: Int = 0
        var isDark: Bool = false
        var tint: UIColor? = nil
        var bg: UIColor? = nil
        var minimize: Int = 3 // automatic

        var unselectedTint: UIColor? = nil

        if let dict = args as? [String: Any] {
            NSLog("📦 TabBar init dict keys: \(dict.keys)")
            labels = (dict["labels"] as? [String]) ?? []
            icons = (dict["icons"] as? [[String: Any]]) ?? []
            searchFlags = (dict["searchFlags"] as? [Bool]) ?? []
            spacerFlags = (dict["spacerFlags"] as? [Bool]) ?? []
            if let badgeData = dict["badgeCounts"] as? [NSNumber?] {
                badgeCounts = badgeData.map { $0?.intValue }
            }
            if let v = dict["selectedIndex"] as? NSNumber { selectedIndex = v.intValue }
            if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
            if let n = dict["tint"] as? NSNumber { tint = Self.colorFromARGB(n.intValue) }
            if let n = dict["unselectedItemTint"] as? NSNumber {
                unselectedTint = Self.colorFromARGB(n.intValue)
                NSLog("🎨 Parsed unselectedItemTint from dict: \(unselectedTint!)")
            }
            if let n = dict["backgroundColor"] as? NSNumber { bg = Self.colorFromARGB(n.intValue) }
            if let m = dict["minimizeBehavior"] as? NSNumber { minimize = m.intValue }
        }

        super.init()

        container.backgroundColor = .clear
        if #available(iOS 13.0, *) {
            container.overrideUserInterfaceStyle = isDark ? .dark : .light
        }


        // Create single tab bar
        let bar = UITabBar(frame: .zero)
        tabBar = bar
        bar.delegate = self
        bar.translatesAutoresizingMaskIntoConstraints = false

        // iOS 26+ special handling - Skip appearance, use direct properties only
        if #available(iOS 26.0, *) {
            // For iOS 26, we skip UITabBarAppearance as it interferes with custom colors
            bar.isTranslucent = true
            bar.backgroundImage = UIImage()
            bar.shadowImage = UIImage()
            bar.backgroundColor = .clear
            NSLog("📱 iOS 26+ detected - using direct properties only")
        }
        // iOS 13-25 - Use appearance
        else if #available(iOS 13.0, *) {
            let appearance = UITabBarAppearance()

            // Make transparent
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            appearance.shadowColor = .clear

            // Set colors directly on the appearance layouts
            let unselColor = unselectedTint ?? UIColor.systemGray
            let selColor = tint ?? UIColor.systemBlue

            // Normal (unselected) items
            appearance.stackedLayoutAppearance.normal.iconColor = unselColor
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselColor]
            appearance.inlineLayoutAppearance.normal.iconColor = unselColor
            appearance.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselColor]
            appearance.compactInlineLayoutAppearance.normal.iconColor = unselColor
            appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselColor]

            // Selected items
            appearance.stackedLayoutAppearance.selected.iconColor = selColor
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selColor]
            appearance.inlineLayoutAppearance.selected.iconColor = selColor
            appearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selColor]
            appearance.compactInlineLayoutAppearance.selected.iconColor = selColor
            appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selColor]

            bar.standardAppearance = appearance
            if #available(iOS 15.0, *) {
                bar.scrollEdgeAppearance = appearance
            }

            NSLog("🎨 iOS 13-25: Applied appearance - normal: \(unselColor), selected: \(selColor)")
        } else {
            // iOS 10-12 fallback
            bar.isTranslucent = true
            bar.backgroundImage = UIImage()
            bar.shadowImage = UIImage()
            bar.backgroundColor = .clear
        }

        // Also set direct properties as fallback
        if #available(iOS 10.0, *) {
            if let unselTint = unselectedTint {
                bar.unselectedItemTintColor = unselTint
                NSLog("✅ Direct unselectedItemTintColor: \(unselTint)")
            }
            if let tint = tint {
                bar.tintColor = tint
                NSLog("✅ Direct tintColor: \(tint)")
            }
        }

        if let bg = bg { bar.barTintColor = bg }

        // Build tab bar items
        func buildItems(_ range: Range<Int>) -> [UITabBarItem] {
            var items: [UITabBarItem] = []
            for i in range {
                let title = (i < labels.count) ? labels[i] : nil
                let isSearch = (i < searchFlags.count) && searchFlags[i]
                let badgeCount = (i < badgeCounts.count) ? badgeCounts[i] : nil

                let item: UITabBarItem

                // Use UITabBarSystemItem.search for search tabs (iOS 26+ Liquid Glass)
                if isSearch {
                    if #available(iOS 26.0, *) {
                        item = UITabBarItem(tabBarSystemItem: .search, tag: i)
                        if let title = title {
                            item.title = title
                        }

                    } else {
                        // Fallback for older iOS versions
                        let searchImage = UIImage(systemName: "magnifyingglass")
                        item = UITabBarItem(title: title, image: searchImage, selectedImage: searchImage)
                    }
                } else {
                    var image: UIImage? = nil
                    var selectedImage: UIImage? = nil

                    // Load icon from icon map
                    if i < icons.count {
                        let iconMap = icons[i]
                        image = self.loadIconImage(from: iconMap, unselectedTint: unselectedTint, isSelected: false)
                        selectedImage = self.loadIconImage(from: iconMap, unselectedTint: unselectedTint, isSelected: true)
                    }

                    // Create item with title
                    item = UITabBarItem(title: title ?? "Tab \(i+1)", image: image, selectedImage: selectedImage)
                    item.tag = i
                }

                // Set badge value if provided
                if let count = badgeCount, count > 0 {
                    item.badgeValue = count > 99 ? "99+" : String(count)
                } else {
                    item.badgeValue = nil
                }

                items.append(item)
            }
            return items
        }

        let count = max(labels.count, icons.count)
        bar.items = buildItems(0..<count)

        // Note: spacerFlags are received but not yet implemented for UITabBar
        // UITabBar doesn't natively support flexible spacing between items like UIToolbar does
        // This would require custom UITabBar subclass or different approach
        // TODO: Implement grouped tab bar layout if needed

        if selectedIndex >= 0, let items = bar.items, selectedIndex < items.count {
            bar.selectedItem = items[selectedIndex]
        }

        container.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bar.topAnchor.constraint(equalTo: container.topAnchor),
            bar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        self.minimizeBehavior = minimize
        self.currentLabels = labels
        self.currentIcons = icons
        self.currentSearchFlags = searchFlags
        self.currentBadgeCounts = badgeCounts

        // Apply minimize behavior if available
        self.applyMinimizeBehavior()

        // Setup method call handler
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { result(nil); return }
            self.handleMethodCall(call, result: result)
        }
    }

    private func applyMinimizeBehavior() {
        // Note: UITabBarController.tabBarMinimizeBehavior is the official iOS 26+ API
        // However, since we're using a standalone UITabBar in a platform view,
        // we need to implement custom minimize behavior
        //
        // The minimize behavior should be controlled at the Flutter level
        // by adjusting the tab bar's height/visibility based on scroll events
        //
        // This method stores the behavior preference for future use
        // The actual minimization animation should be handled by Flutter
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getIntrinsicSize":
            if let bar = self.tabBar {
                let size = bar.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
                result(["width": Double(size.width), "height": Double(size.height)])
            } else {
                result(["width": Double(self.container.bounds.width), "height": 50.0])
            }

        case "setItems":
            guard let args = call.arguments as? [String: Any],
                  let labels = args["labels"] as? [String],
                  let icons = args["icons"] as? [[String: Any]] else {
                result(FlutterError(code: "bad_args", message: "Missing items", details: nil))
                return
            }

            let searchFlags = (args["searchFlags"] as? [Bool]) ?? []
            let selectedIndex = (args["selectedIndex"] as? NSNumber)?.intValue ?? 0
            var badgeCounts: [Int?] = []
            if let badgeData = args["badgeCounts"] as? [NSNumber?] {
                badgeCounts = badgeData.map { $0?.intValue }
            }
            
            self.currentLabels = labels
            self.currentIcons = icons
            self.currentSearchFlags = searchFlags
            self.currentBadgeCounts = badgeCounts

            let count = max(labels.count, icons.count)

            // Reuse the same buildItems function with rendering mode logic
            let buildItems: (Range<Int>) -> [UITabBarItem] = { range in
                var items: [UITabBarItem] = []
                for i in range {
                    let title = (i < labels.count) ? labels[i] : nil
                    let isSearch = (i < searchFlags.count) && searchFlags[i]
                    let badgeCount = (i < badgeCounts.count) ? badgeCounts[i] : nil

                    let item: UITabBarItem

                    // Use UITabBarSystemItem.search for search tabs (iOS 26+ Liquid Glass)
                    if isSearch {
                        if #available(iOS 26.0, *) {
                            item = UITabBarItem(tabBarSystemItem: .search, tag: i)
                            if let title = title {
                                item.title = title
                            }

                        } else {
                            // Fallback for older iOS versions
                            let searchImage = UIImage(systemName: "magnifyingglass")
                            item = UITabBarItem(title: title, image: searchImage, selectedImage: searchImage)
                        }
                    } else {
                        var image: UIImage? = nil
                        var selectedImage: UIImage? = nil

                        // Load icon from icon map
                        if i < icons.count {
                            let iconMap = icons[i]
                            let unselTint = self.tabBar?.unselectedItemTintColor
                            image = self.loadIconImage(from: iconMap, unselectedTint: unselTint, isSelected: false)
                            selectedImage = self.loadIconImage(from: iconMap, unselectedTint: unselTint, isSelected: true)
                        }

                        // Create item with title
                        item = UITabBarItem(title: title ?? "Tab \(i+1)", image: image, selectedImage: selectedImage)
                        item.tag = i
                    }

                    // Set badge value if provided
                    if let count = badgeCount, count > 0 {
                        item.badgeValue = count > 99 ? "99+" : String(count)
                    } else {
                        item.badgeValue = nil
                    }

                    items.append(item)
                }
                return items
            }

            if let bar = self.tabBar {
                bar.items = buildItems(0..<count)
                if let items = bar.items, selectedIndex >= 0, selectedIndex < items.count {
                    bar.selectedItem = items[selectedIndex]
                }
            }
            result(nil)

        case "setSelectedIndex":
            guard let args = call.arguments as? [String: Any],
                  let idx = (args["index"] as? NSNumber)?.intValue else {
                result(FlutterError(code: "bad_args", message: "Invalid index", details: nil))
                return
            }

            if let bar = self.tabBar, let items = bar.items, idx >= 0, idx < items.count {
                bar.selectedItem = items[idx]
            }
            result(nil)

        case "setStyle":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "bad_args", message: "Missing style", details: nil))
                return
            }

            var tintColor: UIColor? = nil
            var unselectedColor: UIColor? = nil

            if let n = args["tint"] as? NSNumber {
                let c = Self.colorFromARGB(n.intValue)
                self.tabBar?.tintColor = c
                tintColor = c
            }
            if let n = args["unselectedItemTint"] as? NSNumber {
                let c = Self.colorFromARGB(n.intValue)
                if #available(iOS 10.0, *) {
                    self.tabBar?.unselectedItemTintColor = c
                    NSLog("✅ setStyle: unselectedItemTintColor set to \(c)")

                    // iOS 26+: Rebuild items with new unselected color
                    if #available(iOS 26.0, *) {
                        self.rebuildItemsWithCurrentColors()
                    }
                }
                unselectedColor = c
            }
            if let n = args["backgroundColor"] as? NSNumber {
                let c = Self.colorFromARGB(n.intValue)
                self.tabBar?.barTintColor = c
            }

            result(nil)

        case "setBrightness":
            guard let args = call.arguments as? [String: Any],
                  let isDark = (args["isDark"] as? NSNumber)?.boolValue else {
                result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil))
                return
            }

            if #available(iOS 13.0, *) {
                self.container.overrideUserInterfaceStyle = isDark ? .dark : .light
            }
            result(nil)

        case "setMinimizeBehavior":
            guard let args = call.arguments as? [String: Any],
                  let behavior = (args["behavior"] as? NSNumber)?.intValue else {
                result(FlutterError(code: "bad_args", message: "Missing behavior", details: nil))
                return
            }

            self.minimizeBehavior = behavior
            self.applyMinimizeBehavior()
            result(nil)

        case "setBadgeCounts":
            guard let args = call.arguments as? [String: Any],
                  let badgeData = args["badgeCounts"] as? [NSNumber?] else {
                result(FlutterError(code: "bad_args", message: "Missing badge counts", details: nil))
                return
            }

            let badgeCounts = badgeData.map { $0?.intValue }
            self.currentBadgeCounts = badgeCounts

            // Update existing tab bar items with new badge values
            if let bar = self.tabBar, let items = bar.items {
                for (index, item) in items.enumerated() {
                    if index < badgeCounts.count {
                        let count = badgeCounts[index]
                        if let count = count, count > 0 {
                            item.badgeValue = count > 99 ? "99+" : String(count)
                        } else {
                            item.badgeValue = nil
                        }
                    }
                }
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // iOS 26+: Rebuild tab items with current colors
    private func rebuildItemsWithCurrentColors() {
        guard let bar = self.tabBar else { return }

        let currentSelectedIndex = bar.items?.firstIndex { $0 == bar.selectedItem } ?? 0
        let unselTint = bar.unselectedItemTintColor

        // Rebuild items with new colors
        var items: [UITabBarItem] = []
        for i in 0..<currentLabels.count {
            let title = currentLabels[i]
            let isSearch = (i < currentSearchFlags.count) && currentSearchFlags[i]
            let badgeCount = (i < currentBadgeCounts.count) ? currentBadgeCounts[i] : nil

            let item: UITabBarItem

            if isSearch {
                if #available(iOS 26.0, *) {
                    item = UITabBarItem(tabBarSystemItem: .search, tag: i)
                    item.title = title
                } else {
                    let searchImage = UIImage(systemName: "magnifyingglass")
                    item = UITabBarItem(title: title, image: searchImage, selectedImage: searchImage)
                }
            } else {
                var image: UIImage? = nil
                var selectedImage: UIImage? = nil

                // Load icon from icon map
                if i < currentIcons.count {
                    let iconMap = currentIcons[i]
                    image = self.loadIconImage(from: iconMap, unselectedTint: unselTint, isSelected: false)
                    selectedImage = self.loadIconImage(from: iconMap, unselectedTint: unselTint, isSelected: true)
                }

                item = UITabBarItem(title: title, image: image, selectedImage: selectedImage)
                item.tag = i
            }

            // Set badge value if provided
            if let count = badgeCount, count > 0 {
                item.badgeValue = count > 99 ? "99+" : String(count)
            }

            items.append(item)
        }

        bar.items = items
        if currentSelectedIndex < items.count {
            bar.selectedItem = items[currentSelectedIndex]
        }
    }

    func view() -> UIView { container }

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        if let bar = self.tabBar, bar === tabBar, let items = bar.items, let idx = items.firstIndex(of: item) {
            channel.invokeMethod("valueChanged", arguments: ["index": idx])
        }
    }

    /// Load icon image from icon map
    private func loadIconImage(from iconMap: [String: Any], unselectedTint: UIColor?, isSelected: Bool) -> UIImage? {
        guard let iconType = iconMap["type"] as? String else { return nil }
        
        let size = (iconMap["size"] as? NSNumber)?.doubleValue ?? 24.0
        let iconColor = (iconMap["color"] as? NSNumber).flatMap { Self.colorFromARGB($0.intValue) }
        
        switch iconType {
        case "sfSymbol":
            guard let symbolName = iconMap["name"] as? String else { return nil }
            return loadSFSymbolIcon(name: symbolName, size: size, color: iconColor, unselectedTint: unselectedTint, isSelected: isSelected)
            
        case "asset":
            guard let assetPath = iconMap["path"] as? String else { return nil }
            return loadAssetIcon(path: assetPath, size: size, color: iconColor)
            
        case "svg":
            guard let svgPath = iconMap["path"] as? String else { return nil }
            return loadSVGIcon(path: svgPath, size: size, color: iconColor)
            
        default:
            return nil
        }
    }
    
    /// Load SF Symbol icon
    private func loadSFSymbolIcon(name: String, size: Double, color: UIColor?, unselectedTint: UIColor?, isSelected: Bool) -> UIImage? {
        // iOS 26+: Use different rendering modes for selected/unselected
        if #available(iOS 26.0, *) {
            if isSelected {
                // Selected: Use template rendering so tintColor applies
                return UIImage(systemName: name)?.withRenderingMode(.alwaysTemplate)
            } else {
                // Unselected: Only apply custom color if unselectedTint is provided
                if let unselTint = unselectedTint {
                    // Create colored image for unselected state
                    if let originalImage = UIImage(systemName: name) {
                        return originalImage.withTintColor(unselTint, renderingMode: .alwaysOriginal)
                    }
                } else {
                    // No custom color - use template mode to respect theme
                    return UIImage(systemName: name)?.withRenderingMode(.alwaysTemplate)
                }
            }
        } else {
            // iOS <26: Use default behavior
            return UIImage(systemName: name)
        }
        return nil
    }
    
    /// Load asset icon (PNG/JPEG)
    private func loadAssetIcon(path: String, size: Double, color: UIColor?) -> UIImage? {
        guard let registrar = registrar else {
            NSLog("⚠️ TabBar: No registrar available for asset loading")
            return nil
        }
        
        // Get the asset lookup key
        let lookupKey = registrar.lookupKey(forAsset: path)
        
        // Try loading from the main bundle
        if let image = UIImage(named: lookupKey, in: Bundle.main, compatibleWith: nil) {
            let resized = resizeImageHighQuality(image, targetSize: CGSize(width: size, height: size))
            
            // Apply color tint if provided
            if let tintColor = color {
                return resized.withTintColor(tintColor, renderingMode: .alwaysTemplate)
            } else {
                return resized.withRenderingMode(.alwaysOriginal)
            }
        }
        
        NSLog("⚠️ TabBar: Failed to load asset icon: \(path)")
        return nil
    }
    
    /// Load SVG icon
    private func loadSVGIcon(path: String, size: Double, color: UIColor?) -> UIImage? {
        #if canImport(SVGKit)
        guard let registrar = registrar else {
            NSLog("⚠️ TabBar: No registrar available for SVG loading")
            return nil
        }
        
        let lookupKey = registrar.lookupKey(forAsset: path)
        
        // Try multiple methods to load SVG from bundle
        var svgImage: SVGKImage?
        var svgPath: String?
        
        // Method 1: Try with lookup key and .svg extension
        if let bundlePath = Bundle.main.path(forResource: lookupKey, ofType: "svg") {
            svgPath = bundlePath
        }
        // Method 2: Try with lookup key without extension
        else if let bundlePath = Bundle.main.path(forResource: lookupKey, ofType: nil) {
            svgPath = bundlePath
        }
        // Method 3: Try with just the filename
        else {
            let assetName = (path as NSString).lastPathComponent
            let assetNameWithoutExt = (assetName as NSString).deletingPathExtension
            
            if let bundlePath = Bundle.main.path(forResource: assetNameWithoutExt, ofType: "svg") {
                svgPath = bundlePath
            } else if let bundlePath = Bundle.main.path(forResource: assetName, ofType: nil) {
                svgPath = bundlePath
            }
        }
        
        // Load SVG if path found
        if let path = svgPath {
            svgImage = SVGKImage(contentsOfFile: path)
        }
        
        // Convert SVG to UIImage with high quality
        if let svg = svgImage {
            // Use screen scale for retina display quality
            let scale = UIScreen.main.scale
            let scaledSize = CGSize(width: size * scale, height: size * scale)
            
            // Set SVG size directly to scaled size for better quality
            svg.size = scaledSize
            
            // Render with high quality using UIGraphicsImageRenderer
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = scale
            format.opaque = false
            
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
            let highQualityImage = renderer.image { context in
                let cgContext = context.cgContext
                
                // Set high quality rendering
                cgContext.interpolationQuality = .none  // For vector graphics, .none is best
                cgContext.setShouldAntialias(true)
                cgContext.setAllowsAntialiasing(true)
                
                // Draw the SVG
                if let svgLayer = svg.caLayerTree {
                    // Scale down to fit in the target size
                    cgContext.scaleBy(x: 1.0 / scale, y: 1.0 / scale)
                    svgLayer.render(in: cgContext)
                }
            }
            
            // Apply color tint if provided
            if let tintColor = color {
                return highQualityImage.withTintColor(tintColor, renderingMode: .alwaysTemplate)
            } else {
                return highQualityImage.withRenderingMode(.alwaysOriginal)
            }
        }
        
        NSLog("⚠️ TabBar: Failed to load SVG icon: \(path)")
        NSLog("   Lookup key: \(lookupKey)")
        #else
        NSLog("⚠️ TabBar: SVGKit not available, cannot load SVG: \(path)")
        #endif
        return nil
    }
    
    /// Resize image with high quality
    private func resizeImageHighQuality(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        // If the image is already close to the target size, don't resize
        if abs(size.width - targetSize.width) < 2 && abs(size.height - targetSize.height) < 2 {
            return image
        }
        
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { context in
            context.cgContext.interpolationQuality = .high
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    static func colorFromARGB(_ argb: Int) -> UIColor {
        let a = CGFloat((argb >> 24) & 0xFF) / 255.0
        let r = CGFloat((argb >> 16) & 0xFF) / 255.0
        let g = CGFloat((argb >> 8) & 0xFF) / 255.0
        let b = CGFloat(argb & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

class iOS26TabBarViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    private weak var registrar: FlutterPluginRegistrar?

    init(messenger: FlutterBinaryMessenger, registrar: FlutterPluginRegistrar?) {
        self.messenger = messenger
        self.registrar = registrar
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return iOS26TabBarPlatformView(
            frame: frame,
            viewId: viewId,
            args: args,
            messenger: messenger,
            registrar: registrar
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
