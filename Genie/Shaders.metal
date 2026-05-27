#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 genieEffect(
    float2 position,
    SwiftUI::Layer layer,
    float2 viewSize,
    float progress,
    float pillRatio,       // unused (kept for arity)
    float restTopY,
    float restBotY,        // unused (kept for arity)
    float diTop,
    float screenH,         // unused (kept for arity)
    float botPower,        // repurposed: stagger spread (0–10)
    float squeezeA,        // repurposed: horizontal scatter range (pts)
    float tailFadeDist     // repurposed: block size (pts)
) {
    float t = progress;

    float BS         = max(tailFadeDist, 4.0);
    float scatterMax = squeezeA;
    float stagger    = botPower * 0.07;         // 0–10 → 0–0.7

    // DI top in view-local Y (negative = above card top)
    float diTop_local = diTop - restTopY;

    // Snap output pixel to block grid
    float2 blockOrigin = floor(position / BS) * BS;
    float2 inBlock     = position - blockOrigin;

    float normX = blockOrigin.x / max(viewSize.x - 1.0, 1.0);
    float normY = blockOrigin.y / max(viewSize.y - 1.0, 1.0);

    // Per-block pseudo-random hash
    float h  = fract(sin(dot(blockOrigin,
                              float2(127.1, 311.7))) * 43758.5453);
    float h2 = fract(sin(dot(blockOrigin + float2(17.0, 53.0),
                              float2(269.5, 183.3))) * 53758.5453);

    // Delay: upper-right corner disintegrates first
    float blockDelay = ((1.0 - normX) * 0.4 + normY * 0.3 + h * 0.3) * stagger;
    blockDelay = saturate(blockDelay);

    float blockT = saturate((t - blockDelay) / max(1.0 - blockDelay, 0.001));

    if (blockT >= 1.0) return half4(0);
    if (blockT <= 0.0) return layer.sample(position);

    // Inverse mapping: find source block position
    //   forward:  x_out = x_src + scatter * blockT
    //             y_out = lerp(y_src, diTop_local, blockT)
    //   inverse:  x_src = x_out - scatter * blockT
    //             y_src = (y_out - diTop_local * blockT) / (1 - blockT)
    float scatterX = (h2 * 2.0 - 1.0) * scatterMax;
    float srcX     = blockOrigin.x - scatterX * blockT;
    float srcY     = (blockOrigin.y - diTop_local * blockT) / max(1.0 - blockT, 0.001);

    if (srcX < 0.0 || srcX >= viewSize.x ||
        srcY < 0.0 || srcY >= viewSize.y) {
        return half4(0);
    }

    // Blend from full-res toward pixelated as block dissolves
    float pixAmt    = saturate(blockT * 5.0);
    float2 fullSrc  = float2(srcX + inBlock.x, srcY + inBlock.y);
    float2 pixSrc   = float2(srcX + BS * 0.5,  srcY + BS * 0.5);
    float2 samplePos = clamp(mix(fullSrc, pixSrc, pixAmt),
                             float2(0.0), viewSize - 1.0);

    float alpha = pow(1.0 - blockT, 1.5);
    return layer.sample(samplePos) * half(alpha);
}
