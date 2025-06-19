import SwiftUI

private struct CurrentAreaNameKey: EnvironmentKey {
    static let defaultValue: String = ""
}

extension EnvironmentValues {
    var currentAreaName: String {
        get { self[CurrentAreaNameKey.self] }
        set { self[CurrentAreaNameKey.self] = newValue }
    }
}
