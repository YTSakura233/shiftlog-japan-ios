import SwiftUI

struct LaunchSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "17385B"), Color(hex: "315C8C"), Color(hex: "5F8DB8")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 310, height: 310)
                .offset(x: -150, y: -310)
                .blur(radius: 2)

            Circle()
                .fill(Color.cyan.opacity(0.13))
                .frame(width: 280, height: 280)
                .offset(x: 170, y: 340)
                .blur(radius: 12)

            VStack(spacing: 26) {
                ZStack {
                    Circle()
                        .trim(from: 0.08, to: 0.82)
                        .stroke(
                            LinearGradient(colors: [.white.opacity(0.9), .cyan.opacity(0.35)], startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 144, height: 144)
                        .rotationEffect(.degrees(revealed ? 300 : -40))

                    Image("LaunchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 112, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(.white.opacity(0.5), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.2), radius: 24, y: 14)
                }
                .scaleEffect(revealed ? 1 : 0.72)
                .opacity(revealed ? 1 : 0)

                VStack(spacing: 9) {
                    Text("app.name")
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("launch.subtitle")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .offset(y: revealed ? 0 : 12)
                .opacity(revealed ? 1 : 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("launch.splash")
        .onAppear {
            if reduceMotion {
                revealed = true
            } else {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.78)) {
                    revealed = true
                }
            }
        }
    }
}
