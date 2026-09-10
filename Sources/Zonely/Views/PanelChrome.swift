import SwiftUI

/// The panel outline: a rounded body with an arrow pointing up at the status
/// item. Drawing it ourselves is the only way the arrow can take a theme colour
/// — NSPopover paints its own arrow in the system material and does not expose it.
struct PanelChromeShape: Shape {
    var arrowX: CGFloat
    var radius: CGFloat
    var arrowWidth: CGFloat = 22
    var arrowHeight: CGFloat = 9

    func path(in rect: CGRect) -> Path {
        let body = CGRect(
            x: rect.minX, y: rect.minY + arrowHeight,
            width: rect.width, height: rect.height - arrowHeight
        )
        let r = min(radius, min(body.width, body.height) / 2)

        // Keep the arrow clear of the rounded corners.
        let limit = r + arrowWidth / 2 + 2
        let x = min(max(arrowX, body.minX + limit), body.maxX - limit)
        let tipInset: CGFloat = 3

        // One continuous outline. Drawing the body and the arrow as two
        // subpaths fills correctly but strokes both, which puts a border line
        // straight across the base of the arrow.
        var path = Path()
        path.move(to: CGPoint(x: body.minX + r, y: body.minY))
        path.addLine(to: CGPoint(x: x - arrowWidth / 2, y: body.minY))
        path.addLine(to: CGPoint(x: x - tipInset, y: rect.minY + tipInset * 0.8))
        path.addQuadCurve(
            to: CGPoint(x: x + tipInset, y: rect.minY + tipInset * 0.8),
            control: CGPoint(x: x, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: x + arrowWidth / 2, y: body.minY))

        path.addLine(to: CGPoint(x: body.maxX - r, y: body.minY))
        path.addArc(tangent1End: CGPoint(x: body.maxX, y: body.minY),
                    tangent2End: CGPoint(x: body.maxX, y: body.minY + r), radius: r)
        path.addLine(to: CGPoint(x: body.maxX, y: body.maxY - r))
        path.addArc(tangent1End: CGPoint(x: body.maxX, y: body.maxY),
                    tangent2End: CGPoint(x: body.maxX - r, y: body.maxY), radius: r)
        path.addLine(to: CGPoint(x: body.minX + r, y: body.maxY))
        path.addArc(tangent1End: CGPoint(x: body.minX, y: body.maxY),
                    tangent2End: CGPoint(x: body.minX, y: body.maxY - r), radius: r)
        path.addLine(to: CGPoint(x: body.minX, y: body.minY + r))
        path.addArc(tangent1End: CGPoint(x: body.minX, y: body.minY),
                    tangent2End: CGPoint(x: body.minX + r, y: body.minY), radius: r)
        path.closeSubpath()
        return path
    }
}

/// Wraps the panel content in that shape, so body and arrow share one fill and
/// one hairline border.
struct PanelChrome<Content: View>: View {
    let arrowX: CGFloat
    let theme: Theme
    @ViewBuilder let content: Content

    static var arrowHeight: CGFloat { 9 }

    var body: some View {
        let shape = PanelChromeShape(arrowX: arrowX, radius: theme.cornerRadius)
        content
            .padding(.top, Self.arrowHeight)
            .background {
                if theme.vibrant {
                    VisualEffectView(material: .popover, blending: .behindWindow)
                        .overlay(theme.surfaceColor)
                        .clipShape(shape)
                } else {
                    shape.fill(theme.surfaceColor)
                }
            }
            .overlay {
                shape.stroke(theme.panelBorderColor, lineWidth: 1)
            }
            // AppKit-backed controls — the graphical date picker, segmented
            // pickers, switches — follow the system appearance, not our tokens.
            // Without this a dark theme on a light Mac draws a white calendar
            // inside a dark panel.
            .environment(\.colorScheme, theme.isDark ? .dark : .light)
    }
}
