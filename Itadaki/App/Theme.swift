import SwiftUI
import UIKit

/// The app's look: washi paper, sumi ink and vermilion, with Mincho type for Japanese.
enum Theme {
    /// Screen background: warm paper in light mode, charcoal in dark mode.
    static let paper = dynamic(light: (0.965, 0.949, 0.918), dark: (0.075, 0.07, 0.065))
    /// Surface of cards sitting on the paper.
    static let card = dynamic(light: (1.0, 0.992, 0.978), dark: (0.13, 0.122, 0.112))
    /// Vermilion (朱色), the single accent colour.
    static let accent = dynamic(light: (0.80, 0.22, 0.16), dark: (0.93, 0.36, 0.28))
    /// Sumi ink for primary text on paper.
    static let ink = dynamic(light: (0.13, 0.115, 0.10), dark: (0.95, 0.93, 0.90))
    static let hairline = Color.primary.opacity(0.09)

    static let cardRadius: CGFloat = 22

    /// Mincho (serif) face for Japanese text, scaled with Dynamic Type.
    static func mincho(_ size: CGFloat, relativeTo style: Font.TextStyle = .title2) -> Font {
        .custom("HiraMinProN-W6", size: size, relativeTo: style)
    }

    private static func dynamic(
        light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)
    ) -> Color {
        Color(UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

/// Seigaiha (青海波), the traditional overlapping-wave pattern, drawn faintly.
struct WavePattern: View {
    var radius: CGFloat = 30
    var opacity: Double = 0.06

    var body: some View {
        Canvas { context, size in
            let color = GraphicsContext.Shading.color(Color.primary.opacity(opacity))
            var row = 0
            var y: CGFloat = 0
            while y < size.height + radius {
                var x: CGFloat = row.isMultiple(of: 2) ? 0 : radius
                while x < size.width + radius {
                    for ring in 0..<3 {
                        var path = Path()
                        path.addArc(
                            center: CGPoint(x: x, y: y),
                            radius: radius - CGFloat(ring) * (radius / 3.5),
                            startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                        context.stroke(path, with: color, lineWidth: 1)
                    }
                    x += radius * 2
                }
                y += radius / 2
                row += 1
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The app's emblem: 頂 ("itadaki") as a vermilion seal.
struct SealEmblem: View {
    var size: CGFloat = 132

    var body: some View {
        ZStack {
            Circle().fill(Theme.accent)
            Circle()
                .strokeBorder(.white.opacity(0.55), lineWidth: size * 0.018)
                .padding(size * 0.07)
            Text("頂")
                .font(.custom("HiraMinProN-W6", fixedSize: size * 0.56))
                .foregroundStyle(.white)
                .environment(\.locale, Locale(identifier: "ja"))
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.accent.opacity(0.35), radius: size * 0.14, y: size * 0.07)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Paper card: rounded surface with a hairline edge and a soft shadow.
    func paperCard(radius: CGFloat = Theme.cardRadius) -> some View {
        background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    /// Paper background with a faint wave pattern, behind a whole screen.
    func paperBackground(pattern: Bool = false) -> some View {
        background {
            ZStack {
                Theme.paper
                if pattern {
                    WavePattern()
                        .mask(
                            LinearGradient(
                                colors: [.black, .black.opacity(0.15)], startPoint: .top, endPoint: .bottom))
                }
            }
            .ignoresSafeArea()
        }
    }
}

/// Primary call to action: full-width vermilion capsule.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Theme.accent, in: Capsule())
            .shadow(color: Theme.accent.opacity(0.35), radius: 12, y: 6)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Secondary action: outlined capsule on paper.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.card, in: Capsule())
            .overlay { Capsule().strokeBorder(Color.primary.opacity(0.14), lineWidth: 1) }
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
