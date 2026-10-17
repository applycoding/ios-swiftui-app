import SwiftUI
import UIKit
import FleetLogCore

enum FleetTheme {
    static let paper = dynamic(light: (0.957, 0.941, 0.902), dark: (0.110, 0.105, 0.098))
    static let card = dynamic(light: (0.988, 0.980, 0.961), dark: (0.165, 0.155, 0.140))
    static let ink = dynamic(light: (0.110, 0.098, 0.082), dark: (0.949, 0.929, 0.890))
    static let inkSoft = dynamic(light: (0.345, 0.310, 0.267), dark: (0.745, 0.706, 0.647))
    static let line = dynamic(light: (0.816, 0.780, 0.714), dark: (0.310, 0.286, 0.247))
    static let pine = dynamic(light: (0.184, 0.420, 0.310), dark: (0.565, 0.757, 0.620))
    static let amber = dynamic(light: (0.729, 0.337, 0.110), dark: (0.933, 0.620, 0.353))
    static let sea = dynamic(light: (0.176, 0.333, 0.435), dark: (0.620, 0.765, 0.843))
    static let delivered = dynamic(light: (0.420, 0.400, 0.365), dark: (0.690, 0.670, 0.620))

    static func color(for status: TripStatus) -> Color {
        switch status {
        case .scheduled:
            sea
        case .enRoute:
            pine
        case .delayed:
            amber
        case .delivered:
            delivered
        }
    }

    private static func dynamic(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        let lightColor = UIColor(red: light.0, green: light.1, blue: light.2, alpha: 1)
        let darkColor = UIColor(red: dark.0, green: dark.1, blue: dark.2, alpha: 1)
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkColor : lightColor
        })
    }
}

enum FleetFormat {
    static func stamp(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    static func miles(_ miles: Double) -> String {
        "\(Int(miles.rounded())) mi"
    }

    static func temperature(_ value: Double) -> String {
        "\(Int(value.rounded()))°"
    }

    static func wind(_ value: Double) -> String {
        "\(Int(value.rounded())) mph wind"
    }
}
