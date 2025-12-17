import Flutter
import UIKit

#if canImport(SVGKit)
    import SVGKit
#endif

/// Factory for creating iOS 26 native button platform views
class iOS26ButtonViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    private var registrar: FlutterPluginRegistrar

    init(messenger: FlutterBinaryMessenger, registrar: FlutterPluginRegistrar) {
        self.messenger = messenger
        self.registrar = registrar
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return iOS26ButtonView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger,
            registrar: registrar
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

/// Native iOS 26 button implementation with Liquid Glass design
class iOS26ButtonView: NSObject, FlutterPlatformView {
    private var _view: UIView
    private var button: UIButton!
    private var channel: FlutterMethodChannel
    private var buttonId: Int
    private var registrar: FlutterPluginRegistrar

    // Configuration
    private var buttonLabel: String = ""
    private var buttonStyle: String = "filled"
    private var buttonSize: String = "medium"
    private var buttonColor: UIColor = .systemBlue
    private var textColor: UIColor?
    private var isEnabled: Bool = true
    private var isDark: Bool = false
    private var iconName: String?  // For SF Symbols (legacy support)
    private var iconType: String?  // 'sfSymbol', 'asset', or 'svg'
    private var iconAssetPath: String?  // For asset and SVG icons
    private var iconSize: CGFloat?
    private var iconColor: UIColor?
    private var useSmoothRectangleBorder: Bool = true

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger,
        registrar: FlutterPluginRegistrar
    ) {
        _view = UIView(frame: frame)
        self.registrar = registrar

        // Extract configuration from arguments
        if let config = args as? [String: Any] {
            buttonId = config["id"] as? Int ?? 0
            buttonLabel = config["label"] as? String ?? ""
            buttonStyle = config["style"] as? String ?? "filled"
            buttonSize = config["size"] as? String ?? "medium"
            isEnabled = config["enabled"] as? Bool ?? true
            isDark = config["isDark"] as? Bool ?? false

            if let colorHex = config["color"] as? String {
                buttonColor = UIColor(hexString: colorHex) ?? .systemBlue
            }

            if let textColorHex = config["textColor"] as? String {
                textColor = UIColor(hexString: textColorHex)
            }

            // Icon configuration (supports SF Symbol, Asset, and SVG)
            iconType = config["iconType"] as? String
            iconName = config["iconName"] as? String  // Legacy SF Symbol support
            iconAssetPath = config["iconAssetPath"] as? String
            if let size = config["iconSize"] as? Double {
                iconSize = CGFloat(size)
            }
            if let argb = config["iconColor"] as? Int {
                iconColor = UIColor(argb: argb)
            }

            // If iconType is not set but iconName is, assume it's a legacy SF Symbol
            if iconType == nil && iconName != nil {
                iconType = "sfSymbol"
            }

            // Use smooth rectangle border setting
            useSmoothRectangleBorder = config["useSmoothRectangleBorder"] as? Bool ?? true
        } else {
            buttonId = 0
        }

        // Setup method channel for communication
        channel = FlutterMethodChannel(
            name: "adaptive_platform_ui/ios26_button_\(buttonId)",
            binaryMessenger: messenger
        )

        super.init()

        // Create the native button
        createNativeButton()

        // Setup method call handler
        channel.setMethodCallHandler { [weak self] (call, result) in
            self?.handleMethodCall(call, result: result)
        }
    }

    func view() -> UIView {
        return _view
    }

    private func createNativeButton() {
        // Create iOS button with system type
        button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false

        // Set tint color
        button.tintColor = buttonColor

        // Apply iOS 26 liquid glass style using UIButton.Configuration
        applyLiquidGlassStyle()

        // Setup constraints
        _view.addSubview(button)

        // Button should fill container width
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: _view.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: _view.trailingAnchor),
            button.topAnchor.constraint(equalTo: _view.topAnchor),
            button.bottomAnchor.constraint(equalTo: _view.bottomAnchor),
            button.heightAnchor.constraint(equalToConstant: getHeightForSize()),
        ])

        // Low content hugging - button can expand if container wants
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Add tap action
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

        // Add press animation targets
        button.addTarget(self, action: #selector(buttonPressed), for: .touchDown)
        button.addTarget(
            self, action: #selector(buttonReleased),
            for: [.touchUpInside, .touchUpOutside, .touchCancel])

        // Apply enabled state
        button.isEnabled = isEnabled
    }

    private func applyLiquidGlassStyle() {
        // Always use iOS 15+ UIButton.Configuration (works on iOS 15+)
        if #available(iOS 15.0, *) {
            var config: UIButton.Configuration

            // Select configuration based on button style
            // Note: .glass() and .prominentGlass() are only available on iOS 26+
            switch buttonStyle {
            case "filled":
                config = .filled()
            case "tinted":
                config = .tinted()
            case "gray":
                config = .gray()
            case "bordered":
                config = .bordered()
            case "plain":
                config = .plain()
            case "glass":
                if #available(iOS 26.0, *) {
                    config = .glass()
                } else {
                    // Fallback: plain style with background material
                    config = .plain()
                    config.background.visualEffect = UIBlurEffect(style: .systemUltraThinMaterial)
                }
            case "prominentGlass":
                if #available(iOS 26.0, *) {
                    config = .prominentGlass()
                } else {
                    // Fallback: tinted style with thicker material
                    config = .tinted()
                    config.background.visualEffect = UIBlurEffect(style: .systemMaterial)
                }
            default:
                config = .filled()
            }

            // Set title or icon based on configuration
            if let iconType = iconType {
                var finalImage: UIImage?

                switch iconType {
                case "sfSymbol":
                    // SF Symbol icon mode
                    let symbolName = iconName ?? ""
                    if let image = UIImage(systemName: symbolName) {
                        let symbolSize = iconSize ?? 24.0
                        finalImage =
                            image.applyingSymbolConfiguration(
                                UIImage.SymbolConfiguration(pointSize: symbolSize)
                            ) ?? image
                    }

                case "asset":
                    // Asset image mode (PNG, JPEG, etc.)
                    if let assetPath = iconAssetPath {
                        // Load image from Flutter's asset bundle
                        // Use FlutterPluginRegistrar to get the asset lookup key
                        let lookupKey = registrar.lookupKey(forAsset: assetPath)

                        // Try multiple methods to load the asset
                        // Method 1: Try with lookup key from main bundle
                        if let image = UIImage(named: lookupKey) {
                            finalImage = image
                        }
                        // Method 2: Try loading from bundle path
                        else if let bundlePath = Bundle.main.path(
                            forResource: lookupKey, ofType: nil)
                        {
                            finalImage = UIImage(contentsOfFile: bundlePath)
                        }
                        // Method 3: Try with just the filename (Flutter sometimes uses just the filename)
                        else {
                            let assetName = (assetPath as NSString).lastPathComponent
                            let assetNameWithoutExt = (assetName as NSString).deletingPathExtension

                            // Try with full name first
                            if let image = UIImage(named: assetName) {
                                finalImage = image
                            }
                            // Try without extension
                            else if let image = UIImage(named: assetNameWithoutExt) {
                                finalImage = image
                            }
                            // Try with lookup key variations
                            else {
                                // Try with path components
                                let pathComponents = assetPath.components(separatedBy: "/")
                                if pathComponents.count > 0 {
                                    let lastComponent = pathComponents.last!
                                    if let image = UIImage(named: lastComponent) {
                                        finalImage = image
                                    } else {
                                        let lastComponentWithoutExt = (lastComponent as NSString)
                                            .deletingPathExtension
                                        if let image = UIImage(named: lastComponentWithoutExt) {
                                            finalImage = image
                                        }
                                    }
                                }
                            }

                            // Debug: Print if still not found
                            if finalImage == nil {
                                print("⚠️ Could not load asset: \(assetPath)")
                                print("   Lookup key: \(lookupKey)")
                                print("   Asset name: \(assetName)")
                                print("   Trying main bundle resources...")
                            }
                        }

                        // Resize image if needed (only if size is specified and different from original)
                        if let image = finalImage, let size = iconSize {
                            // Only resize if the size is significantly different from the original
                            let originalSize = image.size
                            let targetSize = CGSize(width: size, height: size)
                            if abs(originalSize.width - size) > 1.0
                                || abs(originalSize.height - size) > 1.0
                            {
                                finalImage = resizeImageHighQuality(image, to: targetSize)
                            }
                        }
                    }

                case "svg":
                    // SVG icon mode using SVGKit
                    #if canImport(SVGKit)
                        if let assetPath = iconAssetPath {
                            // Get the asset lookup key from Flutter
                            let lookupKey = registrar.lookupKey(forAsset: assetPath)

                            // Try to load SVG from bundle
                            var svgImage: SVGKImage?
                            var svgPath: String?

                            // Method 1: Try with lookup key and .svg extension
                            if let bundlePath = Bundle.main.path(
                                forResource: lookupKey, ofType: "svg")
                            {
                                svgPath = bundlePath
                            }
                            // Method 2: Try with lookup key without extension
                            else if let bundlePath = Bundle.main.path(
                                forResource: lookupKey, ofType: nil)
                            {
                                svgPath = bundlePath
                            }
                            // Method 3: Try with just the filename
                            else {
                                let assetName = (assetPath as NSString).lastPathComponent
                                let assetNameWithoutExt = (assetName as NSString)
                                    .deletingPathExtension

                                if let bundlePath = Bundle.main.path(
                                    forResource: assetNameWithoutExt, ofType: "svg")
                                {
                                    svgPath = bundlePath
                                } else if let bundlePath = Bundle.main.path(
                                    forResource: assetName, ofType: nil)
                                {
                                    svgPath = bundlePath
                                }
                            }

                            // Load SVG if path found
                            if let path = svgPath {
                                svgImage = SVGKImage(contentsOfFile: path)
                            }

                            // Convert SVG to UIImage with high quality
                            if let svg = svgImage {
                                // Get the size for rendering
                                let targetSize = iconSize ?? 24.0

                                // Use screen scale for retina display quality
                                let scale = UIScreen.main.scale
                                let scaledSize = CGSize(
                                    width: targetSize * scale, height: targetSize * scale)

                                // Set SVG size directly to scaled size for better quality
                                // This renders the SVG at the target resolution from the start
                                svg.size = scaledSize

                                // Configure SVGKit for high quality rendering
                                // Set the scale for rasterization if available
                                if let svgLayer = svg.caLayerTree {
                                    svgLayer.rasterizationScale = scale
                                    svgLayer.contentsScale = scale
                                }

                                // Get the UIImage from SVG at high resolution
                                if let uiImage = svg.uiImage {
                                    // Create a new renderer format with proper scale
                                    let format = UIGraphicsImageRendererFormat()
                                    format.scale = scale
                                    format.opaque = false

                                    // Create renderer with custom format
                                    let renderer = UIGraphicsImageRenderer(
                                        size: scaledSize,
                                        format: format
                                    )

                                    finalImage = renderer.image { context in
                                        // Configure context for high quality vector rendering
                                        let cgContext = context.cgContext
                                        cgContext.interpolationQuality = .none  // No interpolation for vector graphics
                                        cgContext.setShouldAntialias(true)
                                        cgContext.setAllowsAntialiasing(true)

                                        // Draw SVG directly at high resolution
                                        uiImage.draw(in: CGRect(origin: .zero, size: scaledSize))
                                    }

                                    // Ensure the image has the correct scale
                                    if let cgImage = finalImage?.cgImage {
                                        finalImage = UIImage(
                                            cgImage: cgImage,
                                            scale: scale,
                                            orientation: finalImage!.imageOrientation
                                        )
                                    }
                                }
                            } else {
                                print("⚠️ Could not load SVG asset: \(assetPath)")
                                print("   Lookup key: \(lookupKey)")
                                print("   Tried paths with .svg extension and without")
                            }
                        }
                    #else
                        // SVGKit not available - fallback to PNG or show error
                        if let assetPath = iconAssetPath {
                            print("⚠️ SVGKit is not available. SVG support requires SVGKit library.")
                            print("   Asset path: \(assetPath)")
                            print(
                                "   Please install SVGKit via CocoaPods or use PNG assets instead.")

                            // Try to load as PNG fallback
                            let pngPath = (assetPath as NSString).deletingPathExtension + ".png"
                            let lookupKey = registrar.lookupKey(forAsset: pngPath)
                            if let bundlePath = Bundle.main.path(
                                forResource: lookupKey, ofType: nil)
                            {
                                finalImage = UIImage(contentsOfFile: bundlePath)
                            } else if let image = UIImage(named: lookupKey) {
                                finalImage = image
                            }

                            // Resize if needed
                            if let image = finalImage, let size = iconSize {
                                let targetSize = CGSize(width: size, height: size)
                                finalImage = resizeImageHighQuality(image, to: targetSize)
                            }
                        }
                    #endif

                default:
                    break
                }

                // Apply icon color tint if provided
                // Only apply tint if color is explicitly provided
                if let image = finalImage {
                    if let color = iconColor {
                        // Apply tint color with template rendering mode
                        finalImage = image.withTintColor(color, renderingMode: .alwaysTemplate)
                    } else {
                        // Keep original colors if no tint is specified
                        finalImage = image.withRenderingMode(.alwaysOriginal)
                    }
                }

                if let image = finalImage {
                    config.image = image
                    config.title = nil
                    config.attributedTitle = nil
                }
            } else if !buttonLabel.isEmpty {
                // Text label mode
                config.title = buttonLabel

                // Set title font with attributed string
                var attributedTitle = AttributedString(buttonLabel)
                attributedTitle.font = getFontForSize()
                config.attributedTitle = attributedTitle
            }

            // Set corner style based on useSmoothRectangleBorder
            if useSmoothRectangleBorder {
                // Use smooth rectangle border (default iOS style)
                config.cornerStyle = .dynamic
            } else {
                // Use capsule (perfectly circular) shape
                config.cornerStyle = .capsule
            }

            // Set colors based on button style
            if let tint = button.tintColor {
                switch buttonStyle {
                case "filled":
                    config.baseBackgroundColor = tint
                    // Use custom text color if provided, otherwise white
                    config.baseForegroundColor = textColor ?? .white
                case "tinted", "bordered", "gray", "plain":
                    // Use custom text color if provided, otherwise tint
                    config.baseForegroundColor = textColor ?? tint
                case "glass", "prominentGlass":
                    // Glass buttons use tint color or custom text color
                    config.baseForegroundColor = textColor ?? tint
                default:
                    break
                }
            } else if let customTextColor = textColor {
                // If no tint but custom text color exists, use it
                config.baseForegroundColor = customTextColor
            }

            // Set content insets for padding
            config.contentInsets = NSDirectionalEdgeInsets(
                top: 8,
                leading: 16,
                bottom: 8,
                trailing: 16
            )

            // Apply configuration
            button.configuration = config

        } else {
            // Fallback for iOS < 15 (manual styling)
            applyLegacyStyle()
        }
    }

    private func applyLegacyStyle() {
        // Legacy styling for iOS < 15
        button.layer.cornerRadius = getCornerRadiusForSize()
        button.clipsToBounds = true

        button.setTitle(buttonLabel, for: .normal)
        button.titleLabel?.font = getFontForSize()

        switch buttonStyle {
        case "filled":
            button.backgroundColor = buttonColor
            button.setTitleColor(.white, for: .normal)
        case "tinted":
            button.backgroundColor = buttonColor.withAlphaComponent(0.15)
            button.setTitleColor(buttonColor, for: .normal)
        case "gray":
            button.backgroundColor = UIColor.systemGray5
            button.setTitleColor(.label, for: .normal)
        case "bordered":
            button.backgroundColor = .clear
            button.setTitleColor(buttonColor, for: .normal)
            button.layer.borderWidth = 1.5
            button.layer.borderColor = buttonColor.cgColor
        case "plain":
            button.backgroundColor = .clear
            button.setTitleColor(buttonColor, for: .normal)
        case "glass", "prominentGlass":
            // Fallback for glass effects on iOS < 15
            button.backgroundColor = buttonColor.withAlphaComponent(0.2)
            button.setTitleColor(buttonColor, for: .normal)
        default:
            button.backgroundColor = buttonColor
            button.setTitleColor(.white, for: .normal)
        }

        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
    }

    @objc private func buttonPressed() {
        // iOS 26 spring animation on press
        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut) {
            self.button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }

    @objc private func buttonReleased() {
        // Return to normal size with spring effect
        UIView.animate(
            withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5,
            options: .curveEaseInOut
        ) {
            self.button.transform = .identity
        }
    }

    @objc private func buttonTapped() {
        // Notify Flutter side about button press
        channel.invokeMethod("pressed", arguments: nil)

        // Add haptic feedback for iOS 26
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setStyle":
            if let args = call.arguments as? [String: Any],
                let style = args["style"] as? String
            {
                buttonStyle = style
                applyLiquidGlassStyle()
            }
            result(nil)

        case "setLabel":
            if let args = call.arguments as? [String: Any],
                let label = args["label"] as? String
            {
                buttonLabel = label
                button.setTitle(label, for: .normal)
            }
            result(nil)

        case "setEnabled":
            if let args = call.arguments as? [String: Any],
                let enabled = args["enabled"] as? Bool
            {
                isEnabled = enabled
                button.isEnabled = enabled
                button.alpha = enabled ? 1.0 : 0.5
            }
            result(nil)

        case "setColor":
            if let args = call.arguments as? [String: Any],
                let colorHex = args["color"] as? String
            {
                buttonColor = UIColor(hexString: colorHex) ?? .systemBlue
                applyLiquidGlassStyle()
            }
            result(nil)

        case "setIcon":
            if let args = call.arguments as? [String: Any] {
                iconType = args["iconType"] as? String
                iconName = args["iconName"] as? String
                iconAssetPath = args["iconAssetPath"] as? String
                if let size = args["iconSize"] as? Double {
                    iconSize = CGFloat(size)
                }
                if let argb = args["iconColor"] as? Int {
                    iconColor = UIColor(argb: argb)
                }

                // Legacy support: if iconType is not set but iconName is, assume SF Symbol
                if iconType == nil && iconName != nil {
                    iconType = "sfSymbol"
                }

                applyLiquidGlassStyle()
            }
            result(nil)

        case "setUseSmoothRectangleBorder":
            if let args = call.arguments as? [String: Any],
                let useSmoothRect = args["useSmoothRectangleBorder"] as? Bool
            {
                useSmoothRectangleBorder = useSmoothRect
                applyLiquidGlassStyle()
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func getFontForSize() -> UIFont {
        switch buttonSize {
        case "small":
            return .systemFont(ofSize: 13, weight: .medium)
        case "medium":
            return .systemFont(ofSize: 15, weight: .medium)
        case "large":
            return .systemFont(ofSize: 17, weight: .semibold)
        default:
            return .systemFont(ofSize: 15, weight: .medium)
        }
    }

    private func getHeightForSize() -> CGFloat {
        switch buttonSize {
        case "small":
            return 28
        case "medium":
            return 36
        case "large":
            return 44
        default:
            return 36
        }
    }

    private func getCornerRadiusForSize() -> CGFloat {
        switch buttonSize {
        case "small":
            return 8
        case "medium":
            return 10
        case "large":
            return 12
        default:
            return 10
        }
    }
}

/// UIColor extension to parse hex color strings and ARGB integers
extension UIColor {
    convenience init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r: UInt64
        let g: UInt64
        let b: UInt64
        let a: UInt64
        switch hex.count {
        case 6:  // RGB
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 255)
        case 8:  // ARGB or RGBA
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }

    convenience init(argb: Int) {
        let a = CGFloat((argb >> 24) & 0xFF) / 255.0
        let r = CGFloat((argb >> 16) & 0xFF) / 255.0
        let g = CGFloat((argb >> 8) & 0xFF) / 255.0
        let b = CGFloat(argb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

/// Helper function to resize UIImage with high quality
func resizeImageHighQuality(_ image: UIImage, to size: CGSize) -> UIImage? {
    // Use screen scale for better quality on retina displays
    let scale = UIScreen.main.scale
    let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)

    UIGraphicsBeginImageContextWithOptions(scaledSize, false, scale)
    defer { UIGraphicsEndImageContext() }

    // Use high quality interpolation
    let context = UIGraphicsGetCurrentContext()
    context?.interpolationQuality = .high

    image.draw(in: CGRect(origin: .zero, size: scaledSize))
    let scaledImage = UIGraphicsGetImageFromCurrentImageContext()

    // Scale back to point size while maintaining quality
    if let scaled = scaledImage {
        return UIImage(cgImage: scaled.cgImage!, scale: scale, orientation: scaled.imageOrientation)
    }
    return nil
}

/// Legacy resize function (kept for backward compatibility)
func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
    return resizeImageHighQuality(image, to: size)
}
