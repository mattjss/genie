import SwiftUI

struct ContentView: View {
    @State private var progress: Double = 0
    @State private var isCollapsed = false
    @State private var diScale: CGFloat = 1.0
    @State private var showControls = false

    static let defaultDuration:  Double = 0.75
    static let defaultBotPower:  Double = 5.0   // stagger spread (0–10)
    static let defaultSqueezeA:  Double = 20.0  // horizontal scatter in pts
    static let defaultFadeDist:  Double = 10.0  // pixel block size in pts

    @State private var collapseDuration: Double = defaultDuration
    @State private var botPower: Double         = defaultBotPower
    @State private var squeezeA: Double         = defaultSqueezeA
    @State private var tailFadeDist: Double     = defaultFadeDist

    let cardW:  CGFloat = 268
    let cardH:  CGFloat = 268
    let pillW:  CGFloat = 126
    let pillH:  CGFloat = 37

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
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

                // Scrim
                if showControls {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                showControls = false
                            }
                        }
                }

                // Bottom sheet
                if showControls {
                    ControlSheet(
                        collapseDuration: $collapseDuration,
                        botPower: $botPower,
                        squeezeA: $squeezeA,
                        tailFadeDist: $tailFadeDist,
                        defaults: (ContentView.defaultDuration,
                                   ContentView.defaultBotPower,
                                   ContentView.defaultSqueezeA,
                                   ContentView.defaultFadeDist),
                        onClose: {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                showControls = false
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
                }

                // Floating trigger — icon only
                if !showControls {
                    Button {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                            showControls = true
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial, in: Circle())
                            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                    }
                    .padding(.bottom, 44)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                    .zIndex(5)
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }

    func collapse() {
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

struct ControlSheet: View {
    @Binding var collapseDuration: Double
    @Binding var botPower: Double
    @Binding var squeezeA: Double
    @Binding var tailFadeDist: Double
    let defaults: (Double, Double, Double, Double)
    let onClose: () -> Void

    @State private var dragOffset: CGFloat = 0

    func reset() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            collapseDuration = defaults.0
            botPower         = defaults.1
            squeezeA         = defaults.2
            tailFadeDist     = defaults.3
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 20)

            HStack {
                Text("Animation")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Reset") { reset() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.accentColor)
                    .padding(.trailing, 14)
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)

            VStack(spacing: 20) {
                SliderRow(label: "Speed",      value: $collapseDuration, range: 0.2...1.5,  format: "%.2fs")
                SliderRow(label: "Stagger",    value: $botPower,         range: 0.0...10.0, format: "%.1f")
                SliderRow(label: "Scatter",    value: $squeezeA,         range: 0.0...60.0, format: "%.0f")
                SliderRow(label: "Block Size", value: $tailFadeDist,     range: 4...24,     format: "%.0fpt")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 44)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { drag in
                    if drag.translation.height > 0 { dragOffset = drag.translation.height }
                }
                .onEnded { drag in
                    if drag.translation.height > 80 {
                        onClose()
                        dragOffset = 0
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }
}

struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: format, value))
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundColor(.primary)
            }
            Slider(value: $value, in: range)
                .tint(.primary)
        }
    }
}

#Preview {
    ContentView()
}
