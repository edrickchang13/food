import SwiftUI

/// Brief confetti burst celebrating a milestone (e.g. weight goal reached).
///
/// Drops `particleCount` particles from the top of the canvas; each
/// drifts downward with a small horizontal sway and rotates around its
/// center. Fades out near the bottom of the visible area. Total animation
/// runs `duration` seconds, then the overlay self-clears via `onComplete`.
///
/// Drop into any parent as a `.overlay(...)`:
/// ```swift
/// someView
///     .overlay(alignment: .top) {
///         if showConfetti {
///             ConfettiView(onComplete: { showConfetti = false })
///         }
///     }
/// ```
///
/// Respects `accessibilityReduceMotion`: when enabled the overlay renders
/// nothing and immediately calls `onComplete()`. The celebration is
/// purely decorative and never blocks UI underneath (`.allowsHitTesting(false)`).
struct ConfettiView: View {
    var particleCount: Int = 30
    var duration: Double = 2.0
    var palette: [Color] = [
        BulkAITheme.Color.accent,
        BulkAITheme.Color.macroProtein,
        BulkAITheme.Color.macroFat,
        BulkAITheme.Color.macroCarbs,
        BulkAITheme.Color.macroCalories
    ]
    var onComplete: () -> Void = { }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(particles) { particle in
                    Rectangle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size * 0.4)
                        .rotationEffect(.degrees(particle.rotation))
                        .position(particle.position)
                        .opacity(particle.opacity)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { start(in: proxy.size) }
        }
    }

    private func start(in size: CGSize) {
        guard !reduceMotion else {
            onComplete()
            return
        }
        // Seed initial particles at the top of the canvas with random x
        particles = (0..<particleCount).map { _ in
            ConfettiParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: -20
                ),
                size: CGFloat.random(in: 6...12),
                color: palette.randomElement() ?? .white,
                rotation: Double.random(in: 0...360),
                opacity: 1.0
            )
        }
        // Animate each to a target near the bottom + sway + rotation + fade
        withAnimation(.easeOut(duration: duration)) {
            particles = particles.map { p in
                var p = p
                p.position = CGPoint(
                    x: p.position.x + CGFloat.random(in: -40...40),
                    y: size.height + 40
                )
                p.rotation += Double.random(in: 360...720)
                p.opacity = 0
                return p
            }
        }
        // After the animation, self-clear via callback
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            onComplete()
        }
    }
}

private struct ConfettiParticle: Identifiable, Equatable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var color: Color
    var rotation: Double
    var opacity: Double
}

#Preview("ConfettiView") {
    struct Host: View {
        @State private var show = true
        var body: some View {
            ZStack {
                BulkAITheme.Color.background.ignoresSafeArea()
                VStack {
                    Text("Goal reached!")
                        .font(BulkAITheme.Typography.title)
                        .foregroundStyle(.white)
                    Button("Replay") {
                        show = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { show = true }
                    }
                    .foregroundStyle(BulkAITheme.Color.accent)
                }
                if show {
                    ConfettiView(onComplete: { show = false })
                        .ignoresSafeArea()
                }
            }
        }
    }
    return Host()
        .preferredColorScheme(.dark)
}
