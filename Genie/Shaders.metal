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
    float botPower,      // exponent for animBotY lag (1=linear, 3=cubic, higher=more lag)
    float squeezeA,      // horizontal squeeze speed (default 2.2)
    float tailFadeDist   // pt below pill bottom where tail starts fading (default 80)
) {
    float t = progress;

    float py_screen = position.y + restTopY;
    float px = position.x / viewSize.x;

    float animTopY = restTopY + (diTop - restTopY) * t;
    float tN       = pow(t, botPower);
    float animBotY = restBotY + (diTop - restBotY) * tN;

    if (py_screen < animTopY || py_screen > animBotY) return half4(0);

    float py_src = (py_screen - animTopY) / max(animBotY - animTopY, 0.001);

    float c    = saturate(t * squeezeA - py_src * 1.2);
    float rowW = mix(1.0, pillRatio, c);

    float leftEdge  = 0.5 - rowW * 0.5;
    float rightEdge = 0.5 + rowW * 0.5;

    if (px < leftEdge || px > rightEdge) return half4(0);

    float strip = max(rightEdge - leftEdge, 0.001);
    float srcX  = clamp((px - leftEdge) / strip, 0.0, 1.0);

    float aa = smoothstep(0.0, 2.0 / viewSize.x, px - leftEdge)
             * smoothstep(0.0, 2.0 / viewSize.x, rightEdge - px);

    float diBottom  = diTop + 37.0;
    float tailToBot = max(animBotY - diBottom, 0.0);
    float tailFade  = 1.0 - saturate(1.0 - tailToBot / max(tailFadeDist, 1.0)) * py_src;

    float srcY = py_src * viewSize.y;
    half4 color = layer.sample(float2(srcX * viewSize.x, srcY));
    return color * half(aa) * half(tailFade);
}
