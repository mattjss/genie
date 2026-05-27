import SwiftUI

struct ContentView: View {
    @State private var progress: Double = 0
    @State private var isCollapsed = false
    @State private var diScale: CGFloat = 1.0

    let cardW:  CGFloat = 268
    let cardH:  CGFloat = 268
    let pillW:  CGFloat = 126
    let pillH:  CGFloat = 37

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white.ignoresSafeArea()

                // Card — genie distortion, renders BEHIND the DI pill
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
                            .float(Float(geo.size.height))
                        ),
                        maxSampleOffset: CGSize(width: cardW / 2,
                                                height: geo.size.height / 2)
                    )
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .opacity(isCollapsed ? 0 : 1)
                    .onTapGesture { if !isCollapsed { collapse() } }

                // DI pill — always the normal black pill, bounces on absorption
                Capsule()
                    .fill(Color.black)
                    .frame(width: pillW, height: pillH)
                    .scaleEffect(diScale)
                    .position(x: geo.size.width / 2, y: 14 + pillH / 2)

                // Large tap zone for expanding — the DI area is in the system
                // status bar zone so touches don't reliably reach the pill itself
                if isCollapsed {
                    Color.clear
                        .frame(width: geo.size.width, height: 110)
                        .contentShape(Rectangle())
                        .onTapGesture { expand() }
                        .position(x: geo.size.width / 2, y: 55)
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }

    func collapse() {
        withAnimation(.linear(duration: 0.5)) {
            progress = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.47) {
            isCollapsed = true
            progress = 0
            // DI gobbles the card with a satisfying bounce
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
        // Set collapsed state (progress=1) and make visible in the same frame,
        // then animate outward next frame — prevents flash at progress=0.
        progress    = 1.0
        isCollapsed = false
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.45)) {
                self.progress = 0.0
            }
        }
    }
}

#Preview {
    ContentView()
}
