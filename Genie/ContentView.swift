import SwiftUI

// MARK: – Voice Agent State

enum VoiceAgentState: Int, Equatable {
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

    // Maps to voiceWave shader mode param
    var waveMode: Float {
        switch self {
        case .idle:                  return 0
        case .listening:             return 1
        case .thinking, .processing: return 2
        case .speaking:              return 3
        }
    }

    var isActive: Bool { self != .idle }

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
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .frame(width: 4, height: 4)
                    .opacity(i < phase ? 0.85 : 0.18)
                    .scaleEffect(i < phase ? 1.0 : 0.6)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.4))
                withAnimation(.spring(response: 0.22, dampingFraction: 0.65)) {
                    phase = (phase + 1) % 4
                }
            }
        }
    }
}

// MARK: – State Label

private struct VoiceStateLabel: View {
    let state: VoiceAgentState

    var body: some View {
        Group {
            if state != .idle {
                HStack(spacing: 7) {
                    Text(state.label)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.90))
                    AnimatedEllipsis()
                        .foregroundStyle(.white.opacity(0.72))
                }
                .id(state)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.88)),
                    removal:   .opacity.combined(with: .scale(scale: 1.06))
                ))
            }
        }
    }
}

// MARK: – Full-Screen Wave View

private struct VoiceWaveView: View {
    let state: VoiceAgentState
    let intensity: Float

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { ctx in
                let t = Float(
                    ctx.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 3600)
                )
                Rectangle()
                    .fill(Color.black)
                    .colorEffect(
                        ShaderLibrary.voiceWave(
                            .float2(Float(geo.size.width), Float(geo.size.height)),
                            .float(t),
                            .float(state.waveMode),
                            .float(intensity)
                        )
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: – Content View

struct ContentView: View {
    @State private var voiceState: VoiceAgentState = .idle
    @State private var intensity: Float = 0.0
    @State private var demoTimer: Timer?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Deep black base
                Color.black.ignoresSafeArea()

                // Metal wave — edge to edge
                VoiceWaveView(state: voiceState, intensity: intensity)

                // State label — upper-centre
                ZStack {
                    VoiceStateLabel(state: voiceState)
                }
                .animation(.spring(response: 0.38, dampingFraction: 0.78), value: voiceState)
                .position(x: geo.size.width / 2, y: geo.size.height * 0.38)

                // Idle hint — very faint, disappears when active
                if voiceState == .idle {
                    Text("Tap to speak")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.22))
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.38)
                        .transition(.opacity)
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .contentShape(Rectangle())
        .onTapGesture { handleTap() }
    }

    // MARK: – Interaction

    private func handleTap() {
        if voiceState.isActive {
            stopVoice()
        } else {
            startVoice()
        }
    }

    private func startVoice() {
        withAnimation(.easeOut(duration: 0.45)) {
            voiceState = .listening
            intensity  = 0.60
        }
        scheduleDemoTimer()
    }

    private func stopVoice() {
        demoTimer?.invalidate()
        demoTimer = nil
        withAnimation(.easeInOut(duration: 0.55)) {
            voiceState = .idle
            intensity  = 0.0
        }
    }

    private func scheduleDemoTimer() {
        demoTimer?.invalidate()
        demoTimer = Timer.scheduledTimer(withTimeInterval: 3.2, repeats: true) { _ in
            guard voiceState.isActive else { return }
            withAnimation(.easeInOut(duration: 0.60)) {
                voiceState = voiceState.next
                intensity  = Float.random(in: 0.50...0.82)
            }
        }
    }
}

// MARK: – Preview

#Preview {
    ContentView()
}
