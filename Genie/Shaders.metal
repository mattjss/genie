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
    float botPower,   // how long bottom lags (higher = more lag)
    float squeezeA,   // funnel curve steepness
    float sCurve      // S-curve side bulge (classic genie silhouette)
) {
    float t = progress;

    float py_screen = position.y + restTopY;
    float px        = position.x / viewSize.x;   // 0..1 across card

    // Top races to DI immediately; bottom lags on t^botPower
    float animTopY = restTopY + (diTop - restTopY) * t;
    float animBotY = restBotY + (diTop - restBotY) * pow(t, botPower);

    if (py_screen < animTopY || py_screen > animBotY) return half4(0);

    // Normalised row position in live shape: 0 = top (near DI), 1 = bottom
    float py_src = (py_screen - animTopY) / max(animBotY - animTopY, 0.001);

    // Horizontal squeeze — power increases toward bottom so top squeezes fast,
    // bottom barely moves, giving the characteristic elongated funnel
    float rowPow  = 1.0 + py_src * squeezeA;
    float squeeze = pow(t, rowPow);
    float rowW    = mix(1.0, pillRatio, squeeze);

    // Classic genie S-curve: sides bow outward in the middle of the shape.
    // sin(py_src·π) peaks at 0.5 (mid-shape) and is zero at top/bottom.
    // Scales with both t and sCurve so the slider controls how pronounced it is.
    float bend     = sin(py_src * 3.14159) * t * sCurve * 0.001;
    float leftEdge  = 0.5 - rowW * 0.5 - bend;
    float rightEdge = 0.5 + rowW * 0.5 + bend;

    if (px < leftEdge || px > rightEdge) return half4(0);

    float strip = max(rightEdge - leftEdge, 0.001);
    float srcX  = clamp((px - leftEdge) / strip, 0.0, 1.0);
    float srcY  = py_src * viewSize.y;

    // Sub-pixel antialiased edges
    float aa = smoothstep(0.0, 1.5 / viewSize.x, px - leftEdge)
             * smoothstep(0.0, 1.5 / viewSize.x, rightEdge - px);

    return layer.sample(float2(srcX * viewSize.x, srcY)) * half(aa);
}
