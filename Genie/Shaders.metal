#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Genie effect: card at center is distorted into a funnel that narrows upward into the DI.
// position is view-local (0,0 = card top-left). maxSampleOffset extends the canvas upward
// so the shader can paint pixels above the natural card frame.
//
// At progress=0: perfect passthrough — no distortion.
// As progress→1: top races to DI linearly, bottom follows on t^3 (earlier than t^5 so
// shape closes faster near the end, cleanly absorbed behind the DI pill).
[[ stitchable ]] half4 genieEffect(
    float2 position,
    SwiftUI::Layer layer,
    float2 viewSize,    // (cardW, cardH) = (268, 268)
    float progress,
    float pillRatio,    // pillW / cardW = 126/268
    float restTopY,     // screen y of card top  (geo.height/2 - cardH/2)
    float restBotY,     // screen y of card bot  (geo.height/2 + cardH/2)
    float diTop,        // 14.0 — top of DI pill in screen coords
    float screenH
) {
    float t = progress;

    // Screen y of this pixel
    float py_screen = position.y + restTopY;
    float px = position.x / viewSize.x;

    // Animated bounds: top races to DI, bottom lags on t^3
    float animTopY = restTopY + (diTop - restTopY) * t;
    float t3       = t * t * t;
    float animBotY = restBotY + (diTop - restBotY) * t3;

    // Outside active region → transparent
    if (py_screen < animTopY || py_screen > animBotY) return half4(0);

    // Normalized row (0 = top, 1 = bottom of stretched image)
    float py_src = (py_screen - animTopY) / max(animBotY - animTopY, 0.001);

    // Horizontal squeeze: top rows narrow to pill width first
    float c    = saturate(t * 2.2 - py_src * 1.2);
    float rowW = mix(1.0, pillRatio, c);

    float leftEdge  = 0.5 - rowW * 0.5;
    float rightEdge = 0.5 + rowW * 0.5;

    if (px < leftEdge || px > rightEdge) return half4(0);

    // Remap px into source image x
    float strip = max(rightEdge - leftEdge, 0.001);
    float srcX  = clamp((px - leftEdge) / strip, 0.0, 1.0);

    // 2-pixel anti-aliased edges
    float aa = smoothstep(0.0, 2.0 / viewSize.x, px - leftEdge)
             * smoothstep(0.0, 2.0 / viewSize.x, rightEdge - px);

    // Fade out only in the final 20pt before the DI top — keeps genie visible
    // all the way to the DI, then dissolves cleanly as it enters the pill.
    float fadeZone = 20.0;
    float enterPct = saturate((animTopY - diTop) / fadeZone);
    float fade     = enterPct * enterPct;

    // Sample from view-local source coords
    float srcY = py_src * viewSize.y;
    half4 color = layer.sample(float2(srcX * viewSize.x, srcY));
    return color * half(aa) * half(fade);
}
