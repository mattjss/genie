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
    float squeezeA,
    float tailFadeDist
) {
    float t = progress;

    float py_screen = position.y + restTopY;
    float px        = position.x / viewSize.x;

    // Vertical: top moves linearly, bottom lags on t^botPower
    float animTopY = restTopY + (diTop - restTopY) * t;
    float animBotY = restBotY + (diTop - restBotY) * pow(t, botPower);

    if (py_screen < animTopY || py_screen > animBotY) return half4(0);

    // Normalised row: 0 = top of live shape, 1 = bottom
    float py_src = (py_screen - animTopY) / max(animBotY - animTopY, 0.001);

    // Horizontal squeeze: each row follows t^(1 + py_src * squeezeA)
    // Top (py_src=0) → t^1 — squeezes fast
    // Bottom (py_src=1) → t^(1+squeezeA) — barely moves, stays wide until the end
    // Produces genuinely convex curved sides (not straight lines)
    float rowPow  = 1.0 + py_src * squeezeA;
    float squeeze = pow(t, rowPow);
    float rowW    = mix(1.0, pillRatio, squeeze);

    float leftEdge  = 0.5 - rowW * 0.5;
    float rightEdge = 0.5 + rowW * 0.5;

    if (px < leftEdge || px > rightEdge) return half4(0);

    float strip = max(rightEdge - leftEdge, 0.001);
    float srcX  = clamp((px - leftEdge) / strip, 0.0, 1.0);
    float srcY  = py_src * viewSize.y;

    float aa = smoothstep(0.0, 1.5 / viewSize.x, px - leftEdge)
             * smoothstep(0.0, 1.5 / viewSize.x, rightEdge - px);

    half4 color = layer.sample(float2(srcX * viewSize.x, srcY));
    return color * half(aa);
}
