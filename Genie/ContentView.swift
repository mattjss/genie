import SwiftUI

struct ContentView: View {
    @State private var progress: Double = 0
    @State private var isCollapsed = false
    @State private var diScale: CGFloat = 1.0
    @State private var showControls = false

    // Tunable parameters
    @State private var collapseDuration: Double = 0.45
    @State private var botPower: Double = 3.0
    @State private var squeezeA: Double = 2.2
    @State private var tailFadeDist: Double = 80.0

    let cardW:  CGFloat = 268
    let cardH:  CGFloat = 268
    let pillW:  CGFloat = 126
    let pillH:  CGFloat = 37

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white.ignoresSafeArea()

                // Card
                Image("Image")
                    .resizable()
                    .scaledToFill()
                    .frame(width: cardW, height: cardH)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .layerEffect(
                        ShaderLibrary.genieEffect(
                            .float2(Float(cardW), Float(cardH)),
                            .float(Float(progress)),
                            .float(Float(pillW / cardW)),
                            .float(Float(geo.size.height / 2 - cardH / 2)),
                            .float(Float(geo.size.height / 2 + cardH / 2)),
                            .float(14.0),
                            .float(Float(geo.size.height)),
                            .float(Float(botPower)),
                            .float(Float(squeezeA)),
                            .float(Float(tailFadeDist))
                        ),
                        maxSampleOffset: CGSize(width: cardW / 2,
                                                height: geo.size.height / 2)
                    )
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .opacity(isCollapsed ? 0 : 1)
                    .onTapGesture { if !isCollapsed { collapse() } }

                // DI pill
                Capsule()
                    .fill(Color.black)
                    .frame(width: pillW, height: pillH)
                    .scaleEffect(diScale)
                    .position(x: geo.size.width / 2, y: 14 + pillH / 2)

                // Expand tap zone
                if isCollapsed {
                    Color.clear
                        .frame(width: geo.size.width, height: 110)
                        .contentShape(Rectangle())
                        .onTapGesture { expand() }
                        .position(x: geo.size.width / 2, y: 55)
                }

                // Controls toggle button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3)) { showControls.toggle() }
                        } label: {
                            Image(systemName: showControls ? "slider.horizontal.3" : "slider.horizontal.3")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.black)
                                .padding(12)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, showControls ? 0 : 40)
                    }

                    if showControls {
                        ControlPanel(
                            collapseDuration: $collapseDuration,
                            botPower: $botPower,
                            squeezeA: $squeezeA,
                            tailFadeDist: $tailFadeDist
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }

    func collapse() {
        // easeIn: starts slow, accelerates into the DI (suction feel)
        withAnimation(.easeIn(duration: collapseDuration)) {
            progress = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + collapseDuration - 0.03) {
            isCollapsed = true
            progress = 0
            withAnimation(.spring(response: 0.14, dampingFraction: 0.28)) {
                diScale = 1.22
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.52)) {
                    diScale = 1.0
                }
            }
        }
    }

    func expand() {
        progress    = 1.0
        isCollapsed = false
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: collapseDuration)) {
                self.progress = 0.0
            }
        }
    }
}

struct ControlPanel: View {
    @Binding var collapseDuration: Double
    @Binding var botPower: Double
    @Binding var squeezeA: Double
    @Binding var tailFadeDist: Double

    var body: some View {
        VStack(spacing: 14) {
            SliderRow(label: "Speed",        value: $collapseDuration, range: 0.2...1.2,  format: "%.2fs")
            SliderRow(label: "Suck Power",   value: $botPower,         range: 1.0...6.0,  format: "%.1f")
            SliderRow(label: "Squeeze",      value: $squeezeA,         range: 1.0...4.0,  format: "%.1f")
            SliderRow(label: "Fade Zone",    value: $tailFadeDist,     range: 10...200,   format: "%.0fpt")
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 75, alignment: .leading)
            Slider(value: $value, in: range)
            Text(String(format: format, value))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundColor(.primary)
                .frame(width: 48, alignment: .trailing)
        }
    }
}

#Preview {
    ContentView()
}
