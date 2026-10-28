import Foundation
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "AccentColor" asset catalog color resource.
    static let accent = DeveloperToolsSupport.ColorResource(name: "AccentColor", bundle: resourceBundle)

    /// The "LaunchBackground" asset catalog color resource.
    static let launchBackground = DeveloperToolsSupport.ColorResource(name: "LaunchBackground", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "sign-313031" asset catalog image resource.
    static let sign313031 = DeveloperToolsSupport.ImageResource(name: "sign-313031", bundle: resourceBundle)

    /// The "sign-313032" asset catalog image resource.
    static let sign313032 = DeveloperToolsSupport.ImageResource(name: "sign-313032", bundle: resourceBundle)

    /// The "sign-313033" asset catalog image resource.
    static let sign313033 = DeveloperToolsSupport.ImageResource(name: "sign-313033", bundle: resourceBundle)

    /// The "sign-313034" asset catalog image resource.
    static let sign313034 = DeveloperToolsSupport.ImageResource(name: "sign-313034", bundle: resourceBundle)

    /// The "sign-313035" asset catalog image resource.
    static let sign313035 = DeveloperToolsSupport.ImageResource(name: "sign-313035", bundle: resourceBundle)

    /// The "sign-313036" asset catalog image resource.
    static let sign313036 = DeveloperToolsSupport.ImageResource(name: "sign-313036", bundle: resourceBundle)

    /// The "sign-313037" asset catalog image resource.
    static let sign313037 = DeveloperToolsSupport.ImageResource(name: "sign-313037", bundle: resourceBundle)

    /// The "sign-313038" asset catalog image resource.
    static let sign313038 = DeveloperToolsSupport.ImageResource(name: "sign-313038", bundle: resourceBundle)

    /// The "sign-313039" asset catalog image resource.
    static let sign313039 = DeveloperToolsSupport.ImageResource(name: "sign-313039", bundle: resourceBundle)

    /// The "sign-313130" asset catalog image resource.
    static let sign313130 = DeveloperToolsSupport.ImageResource(name: "sign-313130", bundle: resourceBundle)

    /// The "sign-313131" asset catalog image resource.
    static let sign313131 = DeveloperToolsSupport.ImageResource(name: "sign-313131", bundle: resourceBundle)

    /// The "sign-313132" asset catalog image resource.
    static let sign313132 = DeveloperToolsSupport.ImageResource(name: "sign-313132", bundle: resourceBundle)

    /// The "sign-313133" asset catalog image resource.
    static let sign313133 = DeveloperToolsSupport.ImageResource(name: "sign-313133", bundle: resourceBundle)

    /// The "sign-313134" asset catalog image resource.
    static let sign313134 = DeveloperToolsSupport.ImageResource(name: "sign-313134", bundle: resourceBundle)

    /// The "sign-313135" asset catalog image resource.
    static let sign313135 = DeveloperToolsSupport.ImageResource(name: "sign-313135", bundle: resourceBundle)

    /// The "sign-313136" asset catalog image resource.
    static let sign313136 = DeveloperToolsSupport.ImageResource(name: "sign-313136", bundle: resourceBundle)

    /// The "sign-313137" asset catalog image resource.
    static let sign313137 = DeveloperToolsSupport.ImageResource(name: "sign-313137", bundle: resourceBundle)

    /// The "sign-313138" asset catalog image resource.
    static let sign313138 = DeveloperToolsSupport.ImageResource(name: "sign-313138", bundle: resourceBundle)

    /// The "sign-313139" asset catalog image resource.
    static let sign313139 = DeveloperToolsSupport.ImageResource(name: "sign-313139", bundle: resourceBundle)

    /// The "sign-313230" asset catalog image resource.
    static let sign313230 = DeveloperToolsSupport.ImageResource(name: "sign-313230", bundle: resourceBundle)

    /// The "sign-313231" asset catalog image resource.
    static let sign313231 = DeveloperToolsSupport.ImageResource(name: "sign-313231", bundle: resourceBundle)

    /// The "sign-313232" asset catalog image resource.
    static let sign313232 = DeveloperToolsSupport.ImageResource(name: "sign-313232", bundle: resourceBundle)

    /// The "sign-313233" asset catalog image resource.
    static let sign313233 = DeveloperToolsSupport.ImageResource(name: "sign-313233", bundle: resourceBundle)

    /// The "sign-313234" asset catalog image resource.
    static let sign313234 = DeveloperToolsSupport.ImageResource(name: "sign-313234", bundle: resourceBundle)

    /// The "sign-313235" asset catalog image resource.
    static let sign313235 = DeveloperToolsSupport.ImageResource(name: "sign-313235", bundle: resourceBundle)

    /// The "sign-313236" asset catalog image resource.
    static let sign313236 = DeveloperToolsSupport.ImageResource(name: "sign-313236", bundle: resourceBundle)

    /// The "sign-313330" asset catalog image resource.
    static let sign313330 = DeveloperToolsSupport.ImageResource(name: "sign-313330", bundle: resourceBundle)

    /// The "sign-313331" asset catalog image resource.
    static let sign313331 = DeveloperToolsSupport.ImageResource(name: "sign-313331", bundle: resourceBundle)

    /// The "sign-313332" asset catalog image resource.
    static let sign313332 = DeveloperToolsSupport.ImageResource(name: "sign-313332", bundle: resourceBundle)

    /// The "sign-313333" asset catalog image resource.
    static let sign313333 = DeveloperToolsSupport.ImageResource(name: "sign-313333", bundle: resourceBundle)

    /// The "sign-313334" asset catalog image resource.
    static let sign313334 = DeveloperToolsSupport.ImageResource(name: "sign-313334", bundle: resourceBundle)

    /// The "sign-313335" asset catalog image resource.
    static let sign313335 = DeveloperToolsSupport.ImageResource(name: "sign-313335", bundle: resourceBundle)

    /// The "sign-313336" asset catalog image resource.
    static let sign313336 = DeveloperToolsSupport.ImageResource(name: "sign-313336", bundle: resourceBundle)

    /// The "sign-313337" asset catalog image resource.
    static let sign313337 = DeveloperToolsSupport.ImageResource(name: "sign-313337", bundle: resourceBundle)

    /// The "sign-313338" asset catalog image resource.
    static let sign313338 = DeveloperToolsSupport.ImageResource(name: "sign-313338", bundle: resourceBundle)

    /// The "sign-313339" asset catalog image resource.
    static let sign313339 = DeveloperToolsSupport.ImageResource(name: "sign-313339", bundle: resourceBundle)

    /// The "sign-313430" asset catalog image resource.
    static let sign313430 = DeveloperToolsSupport.ImageResource(name: "sign-313430", bundle: resourceBundle)

    /// The "sign-313431" asset catalog image resource.
    static let sign313431 = DeveloperToolsSupport.ImageResource(name: "sign-313431", bundle: resourceBundle)

    /// The "sign-313432" asset catalog image resource.
    static let sign313432 = DeveloperToolsSupport.ImageResource(name: "sign-313432", bundle: resourceBundle)

    /// The "sign-313433" asset catalog image resource.
    static let sign313433 = DeveloperToolsSupport.ImageResource(name: "sign-313433", bundle: resourceBundle)

    /// The "sign-313434" asset catalog image resource.
    static let sign313434 = DeveloperToolsSupport.ImageResource(name: "sign-313434", bundle: resourceBundle)

    /// The "sign-313435" asset catalog image resource.
    static let sign313435 = DeveloperToolsSupport.ImageResource(name: "sign-313435", bundle: resourceBundle)

    /// The "sign-313437" asset catalog image resource.
    static let sign313437 = DeveloperToolsSupport.ImageResource(name: "sign-313437", bundle: resourceBundle)

    /// The "sign-313438" asset catalog image resource.
    static let sign313438 = DeveloperToolsSupport.ImageResource(name: "sign-313438", bundle: resourceBundle)

    /// The "sign-313439" asset catalog image resource.
    static let sign313439 = DeveloperToolsSupport.ImageResource(name: "sign-313439", bundle: resourceBundle)

    /// The "sign-313530" asset catalog image resource.
    static let sign313530 = DeveloperToolsSupport.ImageResource(name: "sign-313530", bundle: resourceBundle)

    /// The "sign-313531" asset catalog image resource.
    static let sign313531 = DeveloperToolsSupport.ImageResource(name: "sign-313531", bundle: resourceBundle)

    /// The "sign-313533" asset catalog image resource.
    static let sign313533 = DeveloperToolsSupport.ImageResource(name: "sign-313533", bundle: resourceBundle)

    /// The "sign-323031" asset catalog image resource.
    static let sign323031 = DeveloperToolsSupport.ImageResource(name: "sign-323031", bundle: resourceBundle)

    /// The "sign-323032" asset catalog image resource.
    static let sign323032 = DeveloperToolsSupport.ImageResource(name: "sign-323032", bundle: resourceBundle)

    /// The "sign-323033" asset catalog image resource.
    static let sign323033 = DeveloperToolsSupport.ImageResource(name: "sign-323033", bundle: resourceBundle)

    /// The "sign-323034" asset catalog image resource.
    static let sign323034 = DeveloperToolsSupport.ImageResource(name: "sign-323034", bundle: resourceBundle)

    /// The "sign-323035" asset catalog image resource.
    static let sign323035 = DeveloperToolsSupport.ImageResource(name: "sign-323035", bundle: resourceBundle)

    /// The "sign-323036" asset catalog image resource.
    static let sign323036 = DeveloperToolsSupport.ImageResource(name: "sign-323036", bundle: resourceBundle)

    /// The "sign-323037" asset catalog image resource.
    static let sign323037 = DeveloperToolsSupport.ImageResource(name: "sign-323037", bundle: resourceBundle)

    /// The "sign-323038" asset catalog image resource.
    static let sign323038 = DeveloperToolsSupport.ImageResource(name: "sign-323038", bundle: resourceBundle)

    /// The "sign-323039" asset catalog image resource.
    static let sign323039 = DeveloperToolsSupport.ImageResource(name: "sign-323039", bundle: resourceBundle)

    /// The "sign-323130" asset catalog image resource.
    static let sign323130 = DeveloperToolsSupport.ImageResource(name: "sign-323130", bundle: resourceBundle)

    /// The "sign-323131" asset catalog image resource.
    static let sign323131 = DeveloperToolsSupport.ImageResource(name: "sign-323131", bundle: resourceBundle)

    /// The "sign-323132" asset catalog image resource.
    static let sign323132 = DeveloperToolsSupport.ImageResource(name: "sign-323132", bundle: resourceBundle)

    /// The "sign-323133" asset catalog image resource.
    static let sign323133 = DeveloperToolsSupport.ImageResource(name: "sign-323133", bundle: resourceBundle)

    /// The "sign-323134" asset catalog image resource.
    static let sign323134 = DeveloperToolsSupport.ImageResource(name: "sign-323134", bundle: resourceBundle)

    /// The "sign-323135" asset catalog image resource.
    static let sign323135 = DeveloperToolsSupport.ImageResource(name: "sign-323135", bundle: resourceBundle)

    /// The "sign-323136" asset catalog image resource.
    static let sign323136 = DeveloperToolsSupport.ImageResource(name: "sign-323136", bundle: resourceBundle)

    /// The "sign-323137" asset catalog image resource.
    static let sign323137 = DeveloperToolsSupport.ImageResource(name: "sign-323137", bundle: resourceBundle)

    /// The "sign-323138" asset catalog image resource.
    static let sign323138 = DeveloperToolsSupport.ImageResource(name: "sign-323138", bundle: resourceBundle)

    /// The "sign-323139" asset catalog image resource.
    static let sign323139 = DeveloperToolsSupport.ImageResource(name: "sign-323139", bundle: resourceBundle)

    /// The "sign-323230" asset catalog image resource.
    static let sign323230 = DeveloperToolsSupport.ImageResource(name: "sign-323230", bundle: resourceBundle)

    /// The "sign-323231" asset catalog image resource.
    static let sign323231 = DeveloperToolsSupport.ImageResource(name: "sign-323231", bundle: resourceBundle)

    /// The "sign-323232" asset catalog image resource.
    static let sign323232 = DeveloperToolsSupport.ImageResource(name: "sign-323232", bundle: resourceBundle)

    /// The "sign-323233" asset catalog image resource.
    static let sign323233 = DeveloperToolsSupport.ImageResource(name: "sign-323233", bundle: resourceBundle)

    /// The "sign-323234" asset catalog image resource.
    static let sign323234 = DeveloperToolsSupport.ImageResource(name: "sign-323234", bundle: resourceBundle)

    /// The "sign-323235" asset catalog image resource.
    static let sign323235 = DeveloperToolsSupport.ImageResource(name: "sign-323235", bundle: resourceBundle)

    /// The "sign-323236" asset catalog image resource.
    static let sign323236 = DeveloperToolsSupport.ImageResource(name: "sign-323236", bundle: resourceBundle)

    /// The "sign-323237" asset catalog image resource.
    static let sign323237 = DeveloperToolsSupport.ImageResource(name: "sign-323237", bundle: resourceBundle)

    /// The "sign-323238" asset catalog image resource.
    static let sign323238 = DeveloperToolsSupport.ImageResource(name: "sign-323238", bundle: resourceBundle)

    /// The "sign-323239" asset catalog image resource.
    static let sign323239 = DeveloperToolsSupport.ImageResource(name: "sign-323239", bundle: resourceBundle)

    /// The "sign-333031" asset catalog image resource.
    static let sign333031 = DeveloperToolsSupport.ImageResource(name: "sign-333031", bundle: resourceBundle)

    /// The "sign-333032" asset catalog image resource.
    static let sign333032 = DeveloperToolsSupport.ImageResource(name: "sign-333032", bundle: resourceBundle)

    /// The "sign-333033" asset catalog image resource.
    static let sign333033 = DeveloperToolsSupport.ImageResource(name: "sign-333033", bundle: resourceBundle)

    /// The "sign-333034" asset catalog image resource.
    static let sign333034 = DeveloperToolsSupport.ImageResource(name: "sign-333034", bundle: resourceBundle)

    /// The "sign-333035" asset catalog image resource.
    static let sign333035 = DeveloperToolsSupport.ImageResource(name: "sign-333035", bundle: resourceBundle)

    /// The "sign-333036" asset catalog image resource.
    static let sign333036 = DeveloperToolsSupport.ImageResource(name: "sign-333036", bundle: resourceBundle)

    /// The "sign-333037" asset catalog image resource.
    static let sign333037 = DeveloperToolsSupport.ImageResource(name: "sign-333037", bundle: resourceBundle)

    /// The "sign-333038" asset catalog image resource.
    static let sign333038 = DeveloperToolsSupport.ImageResource(name: "sign-333038", bundle: resourceBundle)

    /// The "sign-333039" asset catalog image resource.
    static let sign333039 = DeveloperToolsSupport.ImageResource(name: "sign-333039", bundle: resourceBundle)

    /// The "sign-333130" asset catalog image resource.
    static let sign333130 = DeveloperToolsSupport.ImageResource(name: "sign-333130", bundle: resourceBundle)

    /// The "sign-343031" asset catalog image resource.
    static let sign343031 = DeveloperToolsSupport.ImageResource(name: "sign-343031", bundle: resourceBundle)

    /// The "sign-343032" asset catalog image resource.
    static let sign343032 = DeveloperToolsSupport.ImageResource(name: "sign-343032", bundle: resourceBundle)

    /// The "sign-343033" asset catalog image resource.
    static let sign343033 = DeveloperToolsSupport.ImageResource(name: "sign-343033", bundle: resourceBundle)

    /// The "sign-343034" asset catalog image resource.
    static let sign343034 = DeveloperToolsSupport.ImageResource(name: "sign-343034", bundle: resourceBundle)

    /// The "sign-343035" asset catalog image resource.
    static let sign343035 = DeveloperToolsSupport.ImageResource(name: "sign-343035", bundle: resourceBundle)

    /// The "sign-343036" asset catalog image resource.
    static let sign343036 = DeveloperToolsSupport.ImageResource(name: "sign-343036", bundle: resourceBundle)

    /// The "sign-343037" asset catalog image resource.
    static let sign343037 = DeveloperToolsSupport.ImageResource(name: "sign-343037", bundle: resourceBundle)

    /// The "sign-343038" asset catalog image resource.
    static let sign343038 = DeveloperToolsSupport.ImageResource(name: "sign-343038", bundle: resourceBundle)

    /// The "sign-343039" asset catalog image resource.
    static let sign343039 = DeveloperToolsSupport.ImageResource(name: "sign-343039", bundle: resourceBundle)

    /// The "sign-343130" asset catalog image resource.
    static let sign343130 = DeveloperToolsSupport.ImageResource(name: "sign-343130", bundle: resourceBundle)

    /// The "sign-343131" asset catalog image resource.
    static let sign343131 = DeveloperToolsSupport.ImageResource(name: "sign-343131", bundle: resourceBundle)

    /// The "sign-343132" asset catalog image resource.
    static let sign343132 = DeveloperToolsSupport.ImageResource(name: "sign-343132", bundle: resourceBundle)

    /// The "sign-343133" asset catalog image resource.
    static let sign343133 = DeveloperToolsSupport.ImageResource(name: "sign-343133", bundle: resourceBundle)

    /// The "sign-343134" asset catalog image resource.
    static let sign343134 = DeveloperToolsSupport.ImageResource(name: "sign-343134", bundle: resourceBundle)

    /// The "sign-343135" asset catalog image resource.
    static let sign343135 = DeveloperToolsSupport.ImageResource(name: "sign-343135", bundle: resourceBundle)

    /// The "sign-343136" asset catalog image resource.
    static let sign343136 = DeveloperToolsSupport.ImageResource(name: "sign-343136", bundle: resourceBundle)

    /// The "sign-343137" asset catalog image resource.
    static let sign343137 = DeveloperToolsSupport.ImageResource(name: "sign-343137", bundle: resourceBundle)

    /// The "sign-343138" asset catalog image resource.
    static let sign343138 = DeveloperToolsSupport.ImageResource(name: "sign-343138", bundle: resourceBundle)

    /// The "sign-343139" asset catalog image resource.
    static let sign343139 = DeveloperToolsSupport.ImageResource(name: "sign-343139", bundle: resourceBundle)

    /// The "sign-343230" asset catalog image resource.
    static let sign343230 = DeveloperToolsSupport.ImageResource(name: "sign-343230", bundle: resourceBundle)

    /// The "sign-343231" asset catalog image resource.
    static let sign343231 = DeveloperToolsSupport.ImageResource(name: "sign-343231", bundle: resourceBundle)

    /// The "sign-343232" asset catalog image resource.
    static let sign343232 = DeveloperToolsSupport.ImageResource(name: "sign-343232", bundle: resourceBundle)

    /// The "sign-343233" asset catalog image resource.
    static let sign343233 = DeveloperToolsSupport.ImageResource(name: "sign-343233", bundle: resourceBundle)

    /// The "sign-343234" asset catalog image resource.
    static let sign343234 = DeveloperToolsSupport.ImageResource(name: "sign-343234", bundle: resourceBundle)

    /// The "sign-343235" asset catalog image resource.
    static let sign343235 = DeveloperToolsSupport.ImageResource(name: "sign-343235", bundle: resourceBundle)

    /// The "sign-343238" asset catalog image resource.
    static let sign343238 = DeveloperToolsSupport.ImageResource(name: "sign-343238", bundle: resourceBundle)

    /// The "sign-343239" asset catalog image resource.
    static let sign343239 = DeveloperToolsSupport.ImageResource(name: "sign-343239", bundle: resourceBundle)

    /// The "sign-343330" asset catalog image resource.
    static let sign343330 = DeveloperToolsSupport.ImageResource(name: "sign-343330", bundle: resourceBundle)

    /// The "sign-343331" asset catalog image resource.
    static let sign343331 = DeveloperToolsSupport.ImageResource(name: "sign-343331", bundle: resourceBundle)

    /// The "sign-343332" asset catalog image resource.
    static let sign343332 = DeveloperToolsSupport.ImageResource(name: "sign-343332", bundle: resourceBundle)

    /// The "sign-343333" asset catalog image resource.
    static let sign343333 = DeveloperToolsSupport.ImageResource(name: "sign-343333", bundle: resourceBundle)

    /// The "sign-343334" asset catalog image resource.
    static let sign343334 = DeveloperToolsSupport.ImageResource(name: "sign-343334", bundle: resourceBundle)

    /// The "sign-343335" asset catalog image resource.
    static let sign343335 = DeveloperToolsSupport.ImageResource(name: "sign-343335", bundle: resourceBundle)

    /// The "sign-343336" asset catalog image resource.
    static let sign343336 = DeveloperToolsSupport.ImageResource(name: "sign-343336", bundle: resourceBundle)

    /// The "sign-343337" asset catalog image resource.
    static let sign343337 = DeveloperToolsSupport.ImageResource(name: "sign-343337", bundle: resourceBundle)

    /// The "sign-343338" asset catalog image resource.
    static let sign343338 = DeveloperToolsSupport.ImageResource(name: "sign-343338", bundle: resourceBundle)

    /// The "sign-343339" asset catalog image resource.
    static let sign343339 = DeveloperToolsSupport.ImageResource(name: "sign-343339", bundle: resourceBundle)

    /// The "sign-343430" asset catalog image resource.
    static let sign343430 = DeveloperToolsSupport.ImageResource(name: "sign-343430", bundle: resourceBundle)

    /// The "sign-343431" asset catalog image resource.
    static let sign343431 = DeveloperToolsSupport.ImageResource(name: "sign-343431", bundle: resourceBundle)

    /// The "sign-353034" asset catalog image resource.
    static let sign353034 = DeveloperToolsSupport.ImageResource(name: "sign-353034", bundle: resourceBundle)

    /// The "sign-353035" asset catalog image resource.
    static let sign353035 = DeveloperToolsSupport.ImageResource(name: "sign-353035", bundle: resourceBundle)

    /// The "sign-363038" asset catalog image resource.
    static let sign363038 = DeveloperToolsSupport.ImageResource(name: "sign-363038", bundle: resourceBundle)

    /// The "sign-363138" asset catalog image resource.
    static let sign363138 = DeveloperToolsSupport.ImageResource(name: "sign-363138", bundle: resourceBundle)

    /// The "sign-363139" asset catalog image resource.
    static let sign363139 = DeveloperToolsSupport.ImageResource(name: "sign-363139", bundle: resourceBundle)

    /// The "sign-363230" asset catalog image resource.
    static let sign363230 = DeveloperToolsSupport.ImageResource(name: "sign-363230", bundle: resourceBundle)

    /// The "sign-363231" asset catalog image resource.
    static let sign363231 = DeveloperToolsSupport.ImageResource(name: "sign-363231", bundle: resourceBundle)

    /// The "sign-363232" asset catalog image resource.
    static let sign363232 = DeveloperToolsSupport.ImageResource(name: "sign-363232", bundle: resourceBundle)

    /// The "sign-363233" asset catalog image resource.
    static let sign363233 = DeveloperToolsSupport.ImageResource(name: "sign-363233", bundle: resourceBundle)

    /// The "sign-363234" asset catalog image resource.
    static let sign363234 = DeveloperToolsSupport.ImageResource(name: "sign-363234", bundle: resourceBundle)

    /// The "sign-363235" asset catalog image resource.
    static let sign363235 = DeveloperToolsSupport.ImageResource(name: "sign-363235", bundle: resourceBundle)

    /// The "sign-363236" asset catalog image resource.
    static let sign363236 = DeveloperToolsSupport.ImageResource(name: "sign-363236", bundle: resourceBundle)

    /// The "sign-363237" asset catalog image resource.
    static let sign363237 = DeveloperToolsSupport.ImageResource(name: "sign-363237", bundle: resourceBundle)

    /// The "sign-363238" asset catalog image resource.
    static let sign363238 = DeveloperToolsSupport.ImageResource(name: "sign-363238", bundle: resourceBundle)

}

