import SwiftUI

// MARK: – Voice Agent State

enum VoiceAgentState: Int, Equatable, CaseIterable {
    case idle       = 0
    case listening  = 1
    case thinking   = 2
    case processing = 3
    case speaking   = 4

    var label: String {
        switch self {
        case .idle:       return ""
        case .listening:  return "Listening"
        case .thinking:   return "Thinking"
        case .processing: return "Processing"
        case .speaking:   return "Speaking"
        }
    }

    // Maps to voiceOrb shader mode param
    var orbMode: Float {
        switch self {
        case .idle:                  return 0
        case .listening:             return 1
        case .thinking, .processing: return 2
        case .speaking:              return 3
        }
    }

    var accentColor: Color {
        switch self {
        case .idle:                  return Color(hue: 0.655, saturation: 0.72, brightness: 0.95)
        case .listening:             return Color(hue: 0.543, saturation: 0.90, brightness: 1.00)
        case .thinking, .processing: return Color(hue: 0.075, saturation: 0.92, brightness: 1.00)
        case .speaking:              return Color(hue: 0.415, saturation: 0.88, brightness: 0.92)
        }
    }

    var isActive: Bool { self != .idle }

    // Demo cycle order
    var next: VoiceAgentState {
        switch self {
        case .idle:       return .listening
        case .listening:  return .thinking
        case .thinking:   return .processing
        case .processing: return .speaking
        case .speaking:   return .listening
        }
    }
}

// MARK: – Animated Ellipsis

private struct AnimatedEllipsis: View {
    let color: Color
    @State private var phase = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.38)) { context in
            let p = Int(context.date.timeIntervalSince1970 / 0.38) % 4
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .frame(width: 4, height: 4)
                        .foregroundStyle(color)
                        .opacity(i < p ? 1.0 : 0.18)
                        .scaleEffect(i < p ? 1.0 : 0.7)
                        .animation(.spring(response: 0.25), value: p)
                }
            }
        }
    }
}

// MARK: – State Label

private struct VoiceStateLabel: View {
    let state: VoiceAgentState

    var body: some View {
        HStack(spacing: 7) {
            if state != .idle {
                Text(state.label)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(state.accentColor)
                AnimatedEllipsis(color: state.accentColor)
            }
        }
        .frame(height: 22)
        .id(state)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .offset(y: 8)).combined(with: .scale(scale: 0.90)),
            removal:   .opacity.combined(with: .offset(y: -8)).combined(with: .scale(scale: 1.08))
        ))
    }
}

// MARK: – Voice Orb (Metal-driven)

private struct VoiceOrbView: View {
    let state: VoiceAgentState
    let intensity: Float
    let size: CGFloat

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = Float(ctx.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 3600))
            Color.clear
                .colorEffect(
                    ShaderLibrary.voiceOrb(
                        .float2(Float(size), Float(size)),
                        .float(t),
                        .float(state.orbMode),
                        .float(intensity)
                    )
                )
        }
        .frame(width: size, height: size)
    }
}

// MARK: – Aurora Background (Metal-driven)

private struct AuroraBackground: View {
    let state: VoiceAgentState
    let intensity: Float

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { ctx in
                let t = Float(ctx.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 3600))
                Color.clear
                    .colorEffect(
                        ShaderLibrary.auroraBackground(
                            .float2(Float(geo.size.width), Float(geo.size.height)),
                            .float(t),
                            .float(state.orbMode),
                            .float(intensity)
                        )
                    )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: – Mic Button

private struct MicButton: View {
    let isActive: Bool
    let onTap: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Pulse ring when active
                if isActive {
                    Circle()
                        .stroke(Color.red.opacity(0.35), lineWidth: 2)
                        .frame(width: 88, height: 88)
                        .scaleEffect(pressed ? 0.92 : 1.0)
                }
                // Main button
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 72, height: 72)
                Circle()
                    .strokeBorder(
                        isActive
                            ? Color.red.opacity(0.75)
                            : Color.white.opacity(0.20),
                        lineWidth: 1.5
                    )
                    .frame(width: 72, height: 72)
                Image(systemName: isActive ? "stop.fill" : "mic.fill")
                    .font(.system(size: 27, weight: .medium))
                    .foregroundStyle(isActive ? .red : .white)
            }
        }
        .scaleEffect(pressed ? 0.90 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.6), value: pressed)
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded   { _ in pressed = false }
        )
    }
}

// MARK: – Status Pill (DI pill with live content)

private struct StatusPill: View {
    let state: VoiceAgentState
    let pillW: CGFloat
    let pillH: CGFloat

    var body: some View {
        ZStack {
            Capsule().fill(Color(white: 0.04))
            Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)

            if state.isActive {
                HStack(spacing: 5) {
                    Circle()
                        .fill(state.accentColor)
                        .frame(width: 6, height: 6)
                        .opacity(0.9)
                    Text(state.label)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .tracking(0.3)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .id(state)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .frame(width: pillW, height: pillH)
    }
}

// MARK: – Content View

struct ContentView: View {
    // Genie animation
    @State private var progress: Double   = 0
    @State private var isCollapsed        = false
    @State private var diScale: CGFloat   = 1.0

    // Voice state
    @State private var voiceState: VoiceAgentState = .idle
    @State private var intensity: Float             = 0.0
    @State private var demoTimer: Timer?

    // Layout constants
    let cardW: CGFloat = 290
    let cardH: CGFloat = 290
    let pillW: CGFloat = 130
    let pillH: CGFloat = 38

    static let collapseSpeed: Double = 0.35

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── Deep black canvas
                Color.black.ignoresSafeArea()

                // ── Metal aurora layer (state-colored, behind everything)
                AuroraBackground(state: voiceState, intensity: intensity)
                    .animation(.easeInOut(duration: 1.0), value: voiceState)

                // ── Voice orb card (subject to genie collapse)
                VoiceOrbView(state: voiceState, intensity: intensity, size: cardW)
                    .layerEffect(
                        ShaderLibrary.genieEffect(
                            .float2(Float(cardW), Float(cardH)),
                            .float(Float(progress)),
                            .float(Float(pillW / cardW)),
                            .float(Float(geo.size.height / 2 - cardH / 2)),
                            .float(Float(geo.size.height / 2 + cardH / 2)),
                            .float(Float(14 + pillH / 2)),
                            .float(Float(geo.size.height)),
                            .float(1.8),
                            .float(4.0),
                            .float(22.0)
                        ),
                        maxSampleOffset: CGSize(width: cardW / 2, height: geo.size.height / 2)
                    )
                    .position(x: geo.size.width / 2,
                              y: geo.size.height / 2)
                    .opacity(isCollapsed ? 0 : 1)
                    .onTapGesture {
                        if !isCollapsed { collapseCard(geo: geo) }
                    }

                // ── State label (below orb)
                if !isCollapsed {
                    ZStack {
                        VoiceStateLabel(state: voiceState)
                    }
                    .position(
                        x: geo.size.width / 2,
                        y: geo.size.height / 2 + cardH / 2 + 44
                    )
                    .animation(.spring(response: 0.38, dampingFraction: 0.78), value: voiceState)
                }

                // ── Mic button (bottom)
                if !isCollapsed {
                    VStack {
                        Spacer()
                        MicButton(isActive: voiceState.isActive) { handleMicTap() }
                            .padding(.bottom, 52)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }

                // ── DI pill (always visible at top)
                StatusPill(state: voiceState, pillW: pillW, pillH: pillH)
                    .scaleEffect(diScale)
                    .position(x: geo.size.width / 2, y: 14 + pillH / 2)
                    .animation(.spring(response: 0.32, dampingFraction: 0.72), value: voiceState)

                // ── Tap-to-expand zone (when collapsed)
                if isCollapsed {
                    Color.clear
                        .frame(width: geo.size.width, height: 120)
                        .contentShape(Rectangle())
                        .onTapGesture { expandCard() }
                        .position(x: geo.size.width / 2, y: 60)
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    // MARK: – Voice Control

    private func handleMicTap() {
        if voiceState.isActive {
            stopVoice()
        } else {
            startVoice()
        }
    }

    private func startVoice() {
        withAnimation(.easeOut(duration: 0.35)) {
            voiceState = .listening
            intensity  = 0.55
        }
        scheduleDemoTimer()
    }

    private func stopVoice() {
        demoTimer?.invalidate()
        demoTimer = nil
        withAnimation(.easeInOut(duration: 0.45)) {
            voiceState = .idle
            intensity  = 0.0
        }
    }

    private func scheduleDemoTimer() {
        demoTimer?.invalidate()
        demoTimer = Timer.scheduledTimer(withTimeInterval: 3.2, repeats: true) { _ in
            guard voiceState.isActive else { return }
            withAnimation(.easeInOut(duration: 0.55)) {
                voiceState = voiceState.next
                // Vary intensity slightly per state for organic feel
                intensity = Float.random(in: 0.45...0.75)
            }
        }
    }

    // MARK: – Genie Collapse / Expand

    private func collapseCard(geo: GeometryProxy) {
        withAnimation(.timingCurve(0.5, 0.0, 0.9, 1.0, duration: Self.collapseSpeed)) {
            progress = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.collapseSpeed - 0.03) {
            isCollapsed = true
            progress    = 0
            withAnimation(.spring(response: 0.12, dampingFraction: 0.25)) { diScale = 1.30 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.52)) { diScale = 1.0 }
            }
        }
    }

    private func expandCard() {
        progress    = 1.0
        isCollapsed = false
        DispatchQueue.main.async {
            withAnimation(.timingCurve(0.1, 0.0, 0.5, 1.0, duration: Self.collapseSpeed * 1.4)) {
                progress = 0.0
            }
        }
    }
}

// MARK: – Preview

#Preview {
    ContentView()
}
