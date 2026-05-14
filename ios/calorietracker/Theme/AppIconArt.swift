import SwiftUI

/// SwiftUI rendering of the Bulk AI app icon. Drawn at 1024×1024 logical
/// points; render via `ImageRenderer` to bake into the asset catalog.
///
/// The design language is a stylized broccoli silhouette on a coral radial
/// gradient. The coral (#FF6B6B → #C13A56) background does the brand-recognition
/// heavy lifting; the white broccoli mark stays legible from the 1024-pt master
/// down to the 29-pt Settings icon.
///
/// Revise this struct rather than editing the rendered PNG directly: the
/// SwiftUI source is the source of truth, the PNG is the export.
///
/// Small-size sanity at 60pt (scale factor = 60/1024 ≈ 0.0586):
///   stem: ~13pt wide × ~19pt tall
///   each floret: ~20-22pt across
///   total mark height: ~38pt — tight but silhouette-readable
struct AppIconArt: View {

    // MARK: - Geometry constants

    /// Canvas side length. The App Store requires exactly 1024 × 1024.
    /// Other sizes (29pt Settings, 40pt Spotlight, 60/76pt Home Screen) are
    /// downscaled by Xcode from this single master.
    static let canvasSize: CGFloat = 1024

    /// Apple's continuous corner radius ratio for iOS app icons (22.37 %).
    private static let cornerRatio: CGFloat = 0.2237

    // MARK: - Body

    var body: some View {
        ZStack {
            background
            broccoliMark
            innerShadowRing
        }
        .frame(width: Self.canvasSize, height: Self.canvasSize)
        .clipShape(
            RoundedRectangle(
                cornerRadius: Self.canvasSize * Self.cornerRatio,
                style: .continuous
            )
        )
        // Xcode re-applies the squircle clip when it injects the icon into the
        // asset catalog; the clip here is for Xcode Previews only.
    }

    // MARK: - Background

    private var background: some View {
        // Radial center offset to the top-left third gives the icon volumetric
        // weight: brightest coral pops in the upper corner, deeper rose sinks
        // toward the lower-right, matching how ambient light would fall.
        RadialGradient(
            gradient: Gradient(colors: [
                Color(red: 1.00, green: 0.42, blue: 0.42),  // #FF6B6B — brand accent
                Color(red: 0.76, green: 0.23, blue: 0.34)   // #C13A56 — deeper rose
            ]),
            center: UnitPoint(x: 0.3, y: 0.3),
            startRadius: 0,
            endRadius: Self.canvasSize * 0.95
        )
    }

    // MARK: - Inner shadow ring

    /// A faint 1pt stroked rounded rectangle, blurred outward, that simulates
    /// the pressed-glass inner shadow iOS applies to real icons. Gives depth
    /// when viewed at 60pt and below without adding noise at 1024pt.
    private var innerShadowRing: some View {
        RoundedRectangle(
            cornerRadius: Self.canvasSize * Self.cornerRatio,
            style: .continuous
        )
        .stroke(Color.black.opacity(0.18), lineWidth: 1)
        .blur(radius: 8)
        .padding(2)
        .allowsHitTesting(false)
    }

    // MARK: - Broccoli mark

    private var broccoliMark: some View {
        let s = Self.canvasSize
        return ZStack {
            // Stem — slightly rounded rectangle, centered just below the canvas
            // midpoint so the floret cluster sits above center (heavier on top,
            // which reads better on Home Screen rows where icons sit above labels).
            stem(scale: s)

            // Three florets: left, right, and top-center.
            // Offsets are fractions of the canvas so the mark scales cleanly.
            floret(scale: s, offsetX: -0.145, offsetY: -0.155, diameter: 0.33)
            floret(scale: s, offsetX:  0.145, offsetY: -0.155, diameter: 0.33)
            floret(scale: s, offsetX:  0.000, offsetY: -0.285, diameter: 0.36)
        }
    }

    // MARK: - Sub-views

    private func stem(scale: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: scale * 0.04, style: .continuous)
            .fill(Color.white.opacity(0.93))
            .frame(width: scale * 0.20, height: scale * 0.30)
            // Offset downward from center so it connects naturally to the florets.
            .offset(y: scale * 0.19)
    }

    /// Single floret: a white circle with a smaller, slightly-offset interior
    /// circle at lower opacity for a soft spherical highlight. The highlight
    /// offsets toward the upper-left, consistent with the background gradient's
    /// light source direction.
    private func floret(
        scale: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat,
        diameter: CGFloat
    ) -> some View {
        let size = scale * diameter
        return ZStack {
            Circle()
                .fill(Color.white.opacity(0.95))

            // Interior highlight — smaller, offset toward the light source.
            Circle()
                .fill(Color.white.opacity(0.50))
                .frame(width: size * 0.42, height: size * 0.42)
                .offset(
                    x: -size * 0.14,
                    y: -size * 0.14
                )
        }
        .frame(width: size, height: size)
        .offset(x: scale * offsetX, y: scale * offsetY)
    }
}

// MARK: - Previews

#Preview("AppIconArt — 1024pt master") {
    AppIconArt()
        .frame(width: AppIconArt.canvasSize, height: AppIconArt.canvasSize)
        .background(Color.gray.opacity(0.2))
}

#Preview("AppIconArt — 60pt home-screen") {
    // Scale the full-resolution view into a 60×60 frame so the preview
    // matches the exact pixel density of the Home Screen icon slot.
    AppIconArt()
        .frame(width: AppIconArt.canvasSize, height: AppIconArt.canvasSize)
        .scaleEffect(60.0 / AppIconArt.canvasSize)
        .frame(width: 60, height: 60)
        .background(Color.gray.opacity(0.15))
}

#Preview("AppIconArt — 29pt Settings") {
    AppIconArt()
        .frame(width: AppIconArt.canvasSize, height: AppIconArt.canvasSize)
        .scaleEffect(29.0 / AppIconArt.canvasSize)
        .frame(width: 29, height: 29)
        .background(Color.gray.opacity(0.15))
}
