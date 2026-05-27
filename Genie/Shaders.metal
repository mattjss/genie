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
    float botPower,     // vertical lag exponent — higher = bottom stays down longer
    float squeezeA,     // side-curve exponent scale — higher = wider funnel for longer
    float tailFadeDist  // unused, kept for control panel compatibility
) {
    float t = progress;

    float py_screen = position.y + restTopY;
    float px        = position.x / viewSize.x;

    // ── Vertical bounds ────────────────────────────────────────────────────────
    // Top races linearly. Bottom lags on t^botPower so it barely moves until
    // the final third, then snaps up — creates the elongated stretch phase.
    float animTopY = restTopY + (diTop - restTopY) * t;
    float animBotY = restBotY + (diTop - restBotY) * pow(t, botPower);

    if (py_screen < animTopY || py_screen > animBotY) return half4(0);

    // Normalised row (0 = top of live shape, 1 = bottom)
    float py_src = (py_screen - animTopY) / max(animBotY - animTopY, 0.001);

    // ── Horizontal squeeze ─────────────────────────────────────────────────────
    // Each row follows t^(1 + py_src * squeezeA):
    //   top (py_src=0)  → t^1  — squeezes immediately and fast
    //   bottom (py_src=1) → t^(1+squeezeA) — extremely slow start, fast finish
    // This makes the sides genuinely convex/curved and the bottom stay wide.
    float rowPow  = 1.0 + py_src * squeezeA;
    float squeeze = pow(t, rowPow);
    float rowW    = mix(1.0, pillRatio, squeeze);

    float leftEdge  = 0.5 - rowW * 0.5;
    float rightEdge = 0.5 + rowW * 0.5;

    if (px < leftEdge || px > rightEdge) return half4(0);

    // ── Source image mapping ───────────────────────────────────────────────────
    float strip = max(rightEdge - leftEdge, 0.001);
    float srcX  = clamp((px - leftEdge) / strip, 0.0, 1.0);
    float srcY  = py_src * viewSize.y;

    // 1-pixel crisp anti-aliased edges
    float aa = smoothstep(0.0, 1.5 / viewSize.x, px - leftEdge)
             * smoothstep(0.0, 1.5 / viewSize.x, rightEdge - px);

    // ── No opacity fade ────────────────────────────────────────────────────────
    // Image stays at full opacity throughout — it disappears only because the
    // DI pill (rendered on top in ZStack) covers it as the genie enters.
    // Only clip the very last pixels right at the DI pill bottom edge so there
    // is no hard seam on the few pixels that slip below the pill before being
    // covered.
    float diBottom   = diTop + 37.0;
    float edgeFade   = smoothstep(diBottom + 4.0, diBottom, py_screen);
    float fade       = mix(1.0, edgeFade, saturate((animTopY - diTop + 20.0) / 20.0));

    half4 color = layer.sample(float2(srcX * viewSize.x, srcY));
    return color * half(aa) * half(fade);
}
