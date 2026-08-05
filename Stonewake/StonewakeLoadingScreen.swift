import SwiftUI

struct StonewakeLoadingScreen: View {
    @State private var ringScale: CGFloat = 0.4
    @State private var ringOpacity: Double = 0.9
    @State private var ringScale2: CGFloat = 0.4
    @State private var ringOpacity2: Double = 0.0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [SW.hex(0xFBE3CD), SW.hex(0xF3CBB0), SW.hex(0x9FC4C0)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    Ellipse()
                        .stroke(Color.white.opacity(ringOpacity), lineWidth: 3)
                        .frame(width: 150, height: 56)
                        .scaleEffect(ringScale)
                    Ellipse()
                        .stroke(Color.white.opacity(ringOpacity2), lineWidth: 2)
                        .frame(width: 150, height: 56)
                        .scaleEffect(ringScale2)
                    Ellipse()
                        .fill(SW.hex(0x7C7468))
                        .frame(width: 44, height: 30)
                        .overlay(
                            Ellipse()
                                .fill(Color.white.opacity(0.35))
                                .frame(width: 18, height: 8)
                                .offset(x: -6, y: -7)
                        )
                }
                .frame(height: 120)

                Text("Stonewake")
                    .font(.custom("Georgia-Bold", size: 28))
                    .foregroundColor(SW.hex(0x3E3830))

                Text("Warming up the water...")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(SW.hex(0x3E3830).opacity(0.55))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                ringScale = 1.7
                ringOpacity = 0.0
            }
            withAnimation(.easeOut(duration: 1.6).delay(0.6).repeatForever(autoreverses: false)) {
                ringScale2 = 1.7
            }
            withAnimation(.linear(duration: 0.05).delay(0.6)) {
                ringOpacity2 = 0.7
            }
        }
    }
}
