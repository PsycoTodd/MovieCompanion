import Foundation

struct MovieLibrary {
    static func displayName(for code: String) -> String {
        switch code.uppercased() {
        case "EN": return "English"
        case "ZH": return "Chinese"
        case "FR": return "French"
        case "ES": return "Spanish"
        case "JA": return "Japanese"
        case "KO": return "Korean"
        case "DE": return "German"
        default: return code.uppercased()
        }
    }
}
