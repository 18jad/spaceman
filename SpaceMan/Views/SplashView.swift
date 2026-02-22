import SwiftUI

struct SplashView: View {
    @Binding var appMode: AppMode
    var namespace: Namespace.ID

    // Icon & text animation
    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var subtitleOpacity: Double = 0

    // Ambient effects
    @State private var glowOpacity: Double = 0
    @State private var backgroundOpacity: Double = 0
    @State private var ring1Active = false
    @State private var ring2Active = false
    @State private var ring3Active = false
    @State private var particleDrift: CGFloat = 0

    private let particles: [(x: CGFloat, y: CGFloat, size: CGFloat, speed: CGFloat)] = [
        (-70, 55, 3, 1.0),
        (85, -35, 2.5, 0.8),
        (-45, -75, 2, 1.3),
        (65, 45, 3, 0.9),
        (-95, -10, 2, 1.1),
        (35, -60, 2.5, 0.7),
        (0, 80, 2, 1.2),
        (-60, 30, 3.5, 0.6),
    ]

    var body: some View {
        ZStack {
            // Radial gradient background
            RadialGradient(
                colors: [Color.accentColor.opacity(0.07), Color.clear],
                center: .center,
                startRadius: 20,
                endRadius: 350
            )
            .opacity(backgroundOpacity)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // Icon composition
                    ZStack {
                        // Pulse rings — staggered sonar effect
                        pulseRing(active: ring1Active)
                        pulseRing(active: ring2Active)
                        pulseRing(active: ring3Active)

                        // Outer soft glow
                        Circle()
                            .fill(Color.accentColor.opacity(0.06))
                            .frame(width: 180, height: 180)
                            .blur(radius: 50)
                            .opacity(glowOpacity)

                        // Inner bright glow
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 90, height: 90)
                            .blur(radius: 20)
                            .opacity(glowOpacity)

                        // Floating particles
                        ForEach(0..<particles.count, id: \.self) { i in
                            Circle()
                                .fill(Color.accentColor.opacity(0.35))
                                .frame(width: particles[i].size, height: particles[i].size)
                                .offset(
                                    x: particles[i].x,
                                    y: particles[i].y - particleDrift * particles[i].speed
                                )
                                .opacity(glowOpacity * 0.7)
                        }

                        // Hero icon — same size as dashboard for seamless transition
                        Image(systemName: "externaldrive.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                            .scaleEffect(iconScale)
                            .opacity(iconOpacity)
                            .matchedGeometryEffect(id: "heroIcon", in: namespace)
                    }
                    .frame(height: 100)

                    VStack(spacing: 10) {
                        // Hero title — same size as dashboard
                        Text("SpaceMan")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .opacity(titleOpacity)
                            .offset(y: titleOffset)
                            .matchedGeometryEffect(id: "heroTitle", in: namespace)

                        // Tagline
                        Text("Reclaim your space")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .opacity(subtitleOpacity)
                    }
                }

                Spacer()
            }
        }
        .onAppear {
            // Background
            withAnimation(.easeIn(duration: 0.6)) {
                backgroundOpacity = 1.0
            }

            // Icon springs in big, then settles
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                iconScale = 1.4
                iconOpacity = 1.0
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.55)) {
                iconScale = 1.0
            }

            // Glow layers fade in
            withAnimation(.easeInOut(duration: 0.8).delay(0.25)) {
                glowOpacity = 1.0
            }

            // Pulse rings — staggered repeating sonar
            withAnimation(.easeOut(duration: 2.2).delay(0.4).repeatForever(autoreverses: false)) {
                ring1Active = true
            }
            withAnimation(.easeOut(duration: 2.2).delay(0.9).repeatForever(autoreverses: false)) {
                ring2Active = true
            }
            withAnimation(.easeOut(duration: 2.2).delay(1.4).repeatForever(autoreverses: false)) {
                ring3Active = true
            }

            // Particles drift upward
            withAnimation(.easeInOut(duration: 2.5).delay(0.3)) {
                particleDrift = 25
            }

            // Title slides up
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                titleOpacity = 1.0
                titleOffset = 0
            }

            // Subtitle fades in
            withAnimation(.easeOut(duration: 0.4).delay(0.8)) {
                subtitleOpacity = 1.0
            }

            // Transition out
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                let hasCompletedOnboarding = AppSettings.hasCompletedOnboarding
                if hasCompletedOnboarding {
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                        appMode = .dashboard
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        appMode = .onboarding
                    }
                }
            }
        }
    }

    private func pulseRing(active: Bool) -> some View {
        Circle()
            .stroke(Color.accentColor.opacity(0.2), lineWidth: 1.5)
            .frame(width: 60, height: 60)
            .scaleEffect(active ? 3.5 : 0.8)
            .opacity(active ? 0 : 0.5)
    }
}
