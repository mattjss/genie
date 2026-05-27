#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 genieEffect(
    float2 position,
    SwiftUI::Layer layer,
    float2 viewSize,
    float progress,
    float pillRatio,   // pillW / cardW
    float restTopY,    // screen-y of card top at rest
    float restBotY,    // screen-y of card bottom at rest
    float diTop,       // screen-y of DI bottom edge (funnel target)
    float screenH,     // full screen height (unused, keeps API stable)
    float botPower,    // how much the bottom lags (lower = faster)
    float squeezeA,    // per-row power spread (higher = more funnel drama)
    float blurMax      // max blur radius in points at t=1
) {
    float t = progress;
    if (t <= 0.0) return layer.sample(position);

    // Convert card-local Y to screen Y
    float py_screen = position.y + restTopY;
    float px        = position.x / viewSize.x;   // 0..1 across card width

    // Animate bounding rows toward DI:
    // Top races there (linear), bottom lags hard (t^botPower)
    float animTopY = restTopY + (diTop - restTopY) * t;
    float animBotY = restBotY + (diTop - restBotY) * pow(t, botPower);

    if (py_screen < animTopY || py_screen > animBotY) return half4(0);

    // Relative position within the current visible strip: 0 = near DI, 1 = bottom
    float py_src = (py_screen - animTopY) / max(animBotY - animTopY, 0.001);

    // --- Per-row horizontal squeeze ---
    // Top rows (py_src=0) use power 0.5 → fast squeeze, reaches pill width by t≈0.5.
    // Bottom rows (py_src=1) use power 0.5+squeezeA → barely move until late.
    float rowPow  = 0.5 + py_src * squeezeA;
    float squeeze = pow(t, rowPow);
    float rowW    = mix(1.0, pillRatio, squeeze);   // 1.0=full card, pillRatio=pill

    float leftEdge  = 0.5 - rowW * 0.5;
    float rightEdge = 0.5 + rowW * 0.5;
    if (px < leftEdge || px > rightEdge) return half4(0);

    // Map the visible strip to source coordinates
    float strip = max(rightEdge - leftEdge, 0.001);
    float srcX  = clamp((px - leftEdge) / strip, 0.0, 1.0);
    float srcY  = py_src * viewSize.y;              // full card content, linearly mapped
    float2 srcPos = float2(srcX * viewSize.x, srcY);
    float2 maxV   = viewSize - 1.0;

    // --- Growing Gaussian blur (fast onset via pow(t, 0.35)) ---
    // Simulates the motion-blur/liquid feel of the reference.
    float blurR = pow(t, 0.35) * blurMax;

    half4 col;
    if (blurR < 0.5) {
        col = layer.sample(clamp(srcPos, float2(0), maxV));
    } else {
        // 9-tap weighted cross blur: center + near ring (r*0.5) + far ring (r)
        float r1 = blurR * 0.5;
        float r2 = blurR;
        col  = layer.sample(clamp(srcPos,                              float2(0), maxV)) * 4.0h;
        col += layer.sample(clamp(srcPos + float2( r1,  0), float2(0), maxV)) * 2.0h;
        col += layer.sample(clamp(srcPos + float2(-r1,  0), float2(0), maxV)) * 2.0h;
        col += layer.sample(clamp(srcPos + float2(  0, r1), float2(0), maxV)) * 2.0h;
        col += layer.sample(clamp(srcPos + float2(  0,-r1), float2(0), maxV)) * 2.0h;
        col += layer.sample(clamp(srcPos + float2( r2,  0), float2(0), maxV));
        col += layer.sample(clamp(srcPos + float2(-r2,  0), float2(0), maxV));
        col += layer.sample(clamp(srcPos + float2(  0, r2), float2(0), maxV));
        col += layer.sample(clamp(srcPos + float2(  0,-r2), float2(0), maxV));
        col /= 16.0h;
    }

    // Soft anti-aliased edges on left/right
    float aa = smoothstep(0.0, 2.0 / viewSize.x, px - leftEdge)
             * smoothstep(0.0, 2.0 / viewSize.x, rightEdge - px);

    return col * half(aa);
}
