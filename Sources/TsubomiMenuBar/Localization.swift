import Foundation

/// この部品の文言。キーは日本語の原文（Profilink・TouchRotator と同じ方式）。
/// 英語は Resources/en.lproj/Localizable.strings。
func L(_ key: String) -> String {
    NSLocalizedString(key, bundle: .module, comment: "")
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: L(key), arguments: arguments)
}
