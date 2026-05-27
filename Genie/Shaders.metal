#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 genieEffect(
    float2 position,
    SwiftUI::Layer layer,
    float2 viewSize,
    float progress,
    float pillRatio,
    float restTopY,
    float restBotY,
    float diTop,
    float screenH,
    float botPower,
    float squeezeZone,
    float unused
) {
    float t = progress;

    float py_screen = position.y + restTopY;
    float px        = position.x / viewSize.x;

    // Top snaps to DI fast; bottom lags on t^botPower
    float animTopY = restTopY + (diTop - restTopY) * t;
    float animBotY = restBotY + (diTop - restBotY) * pow(t, botPower);

    if (py_screen < animTopY || py_screen > animBotY) return half4(0);

    // 0 = top of live shape (near DI), 1 = bottom
    float py_src = (py_screen - animTopY) / max(animBotY - animTopY, 0.001);

    // --- Distance-based horizontal squeeze ---
    // Width at each row is determined by how far it is from the DI opening.
    // Rows close to DI are already pill-width; rows far away stay card-width.
    float dist     = max(py_screen - diTop, 0.0);
    float targetW  = pillRatio + (1.0 - pillRatio) * saturate(dist / max(squeezeZone, 1.0));
    float rowW     = mix(1.0, targetW, t);

    float leftEdge  = 0.5 - rowW * 0.5;
    float rightEdge = 0.5 + rowW * 0.5;

    if (px < leftEdge || px > rightEdge) return half4(0);

    float strip = max(rightEdge - leftEdge, 0.001);
    float srcX  = clamp((px - leftEdge) / strip, 0.0, 1.0);

    // Vertical: remap source row linearly within the original card
    float srcY = py_src * viewSize.y;

    float aa = smoothstep(0.0, 1.5 / viewSize.x, px - leftEdge)
             * smoothstep(0.0, 1.5 / viewSize.x, rightEdge - px);

    return layer.sample(float2(srcX * viewSize.x, srcY)) * half(aa);
}
