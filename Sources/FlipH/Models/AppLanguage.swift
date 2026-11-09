import Foundation

enum AppLanguage: String, CaseIterable {
    case system, en, de, fr, es, ca, it, pt

    func title(in language: AppLanguage) -> String {
        switch self {
        case .system: return language.localized("System Language")
        case .en: return "English"
        case .de: return "Deutsch"
        case .fr: return "Français"
        case .es: return "Español"
        case .ca: return "Català"
        case .it: return "Italiano"
        case .pt: return "Português"
        }
    }

    func localized(_ resource: LocalizedStringResource) -> String {
        var resource = resource
        let identifier = self == .system ? Bundle.main.preferredLocalizations.first ?? "en" : rawValue
        resource.locale = Locale(identifier: identifier)
        return String(localized: resource)
    }
}
