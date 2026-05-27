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
    float botPower,   // bottom lag strength
    float squeezeA,   // funnel steepness
    float sCurve      // portal warp intensity
) {
    float t = progress;

    float py_screen = position.y + restTopY;
    float px        = position.x / viewSize.x;

    // Top races to DI; bottom lags hard on t^botPower
    float animTopY = restTopY + (diTop - restTopY) * t;
    float animBotY = restBotY + (diTop - restBotY) * pow(t, botPower);

    if (py_screen < animTopY || py_screen > animBotY) return half4(0);

    // 0 = top of live shape (near DI), 1 = bottom
    float py_src = (py_screen - animTopY) / max(animBotY - animTopY, 0.001);

    // --- Horizontal funnel ---
    // Top rows squeeze to pill width fast; bottom rows barely move
    float rowPow  = 1.0 + py_src * squeezeA;
    float squeeze = pow(t, rowPow);
    float rowW    = mix(1.0, pillRatio, squeeze);

    // S-curve: sides bow outward in the middle (classic genie silhouette)
    float bend     = sin(py_src * 3.14159) * t * 0.12;
    float leftEdge  = 0.5 - rowW * 0.5 - bend;
    float rightEdge = 0.5 + rowW * 0.5 + bend;

    if (px < leftEdge || px > rightEdge) return half4(0);

    float strip = max(rightEdge - leftEdge, 0.001);
    float srcX  = clamp((px - leftEdge) / strip, 0.0, 1.0);

    // --- Portal warp ---
    // Pixels near the DI (py_src≈0) are pulled toward center,
    // as if being sucked through a hole. Grows stronger over time.
    float portalPull = (1.0 - py_src) * (1.0 - py_src) * t * t * sCurve * 0.008;
    float srcXWarped = 0.5 + (srcX - 0.5) * (1.0 - portalPull);
    srcXWarped = clamp(srcXWarped, 0.0, 1.0);

    // Vertical: slight perspective compression near top
    // Makes content look like it's being pulled through the portal
    float vertWarp = 1.0 - (1.0 - py_src) * t * 0.3;
    float srcY = clamp(py_src * vertWarp, 0.0, 1.0) * viewSize.y;

    float aa = smoothstep(0.0, 1.5 / viewSize.x, px - leftEdge)
             * smoothstep(0.0, 1.5 / viewSize.x, rightEdge - px);

    return layer.sample(float2(srcXWarped * viewSize.x, srcY)) * half(aa);
}
