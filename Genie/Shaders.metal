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
    float botPower,     // vertical lag exponent (3 = cubic, higher = bottom lags more)
    float squeezeA,     // side-curve exponent scale (higher = more convex, bottom stays wide longer)
    float tailFadeDist  // pt below pill bottom where tail begins dissolving
) {
    float t = progress;

    float py_screen = position.y + restTopY;
    float px        = position.x / viewSize.x;

    // Vertical: top races linearly, bottom lags on t^botPower
    float animTopY = restTopY + (diTop - restTopY) * t;
    float animBotY = restBotY + (diTop - restBotY) * pow(t, botPower);

    if (py_screen < animTopY || py_screen > animBotY) return half4(0);

    // Normalised row (0 = top of live shape, 1 = bottom)
    float py_src = (py_screen - animTopY) / max(animBotY - animTopY, 0.001);

    // Phase 1 (t < 0.18): pure vertical stretch, no squeeze — card elongates visibly.
    // Phase 2 (t ≥ 0.18): squeeze kicks in with per-row curved power law.
    // Each row follows tSq^(1 + py_src * squeezeA):
    //   top row squeezes at t^1 (fastest), bottom at t^(1+squeezeA) (slowest → convex sides).
    float tSq     = max(0.0, (t - 0.18) / 0.82);   // remapped squeeze-only progress
    float rowPow  = 1.0 + py_src * squeezeA;
    float squeeze = pow(tSq, rowPow);
    float rowW    = mix(1.0, pillRatio, squeeze);

    float leftEdge  = 0.5 - rowW * 0.5;
    float rightEdge = 0.5 + rowW * 0.5;

    if (px < leftEdge || px > rightEdge) return half4(0);

    float strip = max(rightEdge - leftEdge, 0.001);
    float srcX  = clamp((px - leftEdge) / strip, 0.0, 1.0);

    // 2-pixel anti-aliased edges
    float aa = smoothstep(0.0, 2.0 / viewSize.x, px - leftEdge)
             * smoothstep(0.0, 2.0 / viewSize.x, rightEdge - px);

    // Tail fade: dissolve bottom rows as animBotY approaches DI pill bottom
    float diBottom  = diTop + 37.0;
    float tailToBot = max(animBotY - diBottom, 0.0);
    float tailFade  = 1.0 - saturate(1.0 - tailToBot / max(tailFadeDist, 1.0)) * py_src;

    float srcY = py_src * viewSize.y;
    half4 color = layer.sample(float2(srcX * viewSize.x, srcY));
    return color * half(aa) * half(tailFade);
}
