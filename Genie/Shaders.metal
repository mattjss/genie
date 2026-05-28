#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// ─── Genie Effect (unchanged) ────────────────────────────────────────────────

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
    float blurMax
) {
    float t = progress;
    if (t <= 0.0) return layer.sample(position);

    float py_screen = position.y + restTopY;
    float px        = position.x / viewSize.x;

    float animTopY = restTopY + (diTop - restTopY) * t;
    float animBotY = restBotY + (diTop - restBotY) * pow(t, botPower);

    if (py_screen < animTopY || py_screen > animBotY) return half4(0);

    float py_src = (py_screen - animTopY) / max(animBotY - animTopY, 0.001);

    float rowPow  = 0.5 + py_src * squeezeA;
    float squeeze = pow(t, rowPow);
    float rowW    = mix(1.0, pillRatio, squeeze);

    float leftEdge  = 0.5 - rowW * 0.5;
    float rightEdge = 0.5 + rowW * 0.5;
    if (px < leftEdge || px > rightEdge) return half4(0);

    float strip  = max(rightEdge - leftEdge, 0.001);
    float srcX   = clamp((px - leftEdge) / strip, 0.0, 1.0);
    float srcY   = py_src * viewSize.y;
    float2 srcPos = float2(srcX * viewSize.x, srcY);
    float2 maxV   = viewSize - 1.0;

    float blurR = pow(t, 0.35) * blurMax;

    half4 col;
    if (blurR < 0.5) {
        col = layer.sample(clamp(srcPos, float2(0), maxV));
    } else {
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

    float aa = smoothstep(0.0, 2.0 / viewSize.x, px - leftEdge)
             * smoothstep(0.0, 2.0 / viewSize.x, rightEdge - px);

    return col * half(aa);
}

// ─── Noise Helpers ────────────────────────────────────────────────────────────

static float hash21(float2 p) {
    p = fract(p * float2(127.1, 311.7));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

static float vnoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash21(i + float2(0,0)), hash21(i + float2(1,0)), u.x),
        mix(hash21(i + float2(0,1)), hash21(i + float2(1,1)), u.x),
        u.y
    );
}

static float fbm4(float2 p) {
    float v = 0.0, a = 0.5;
    float2x2 rot = float2x2(1.6,  1.2, -1.2, 1.6); // ~36.87° scaled
    for (int i = 0; i < 4; i++) {
        v += a * vnoise(p);
        p  = rot * p;
        a *= 0.5;
    }
    return v;
}

static float fbm3(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * vnoise(p);
        p *= 2.1;
        a *= 0.5;
    }
    return v;
}

// ─── Voice Orb ───────────────────────────────────────────────────────────────
//
//  mode: 0 = idle, 1 = listening, 2 = thinking/processing, 3 = speaking
//  intensity: 0..1 audio activity level

[[ stitchable ]] half4 voiceOrb(
    float2 position,
    half4  inColor,
    float2 size,
    float  time,
    float  mode,
    float  intensity
) {
    // Centered, aspect-corrected UV
    float2 uv    = (position / size) * 2.0 - 1.0;
    float aspect = size.x / size.y;
    uv.x *= aspect;

    float dist  = length(uv);
    float angle = atan2(uv.y, uv.x);

    // ── Orb radius distortion ──────────────────────────────────────────────
    float noiseAmp   = 0.11 + intensity * 0.09;
    float noiseSpeed = 0.55 + intensity * 0.90;
    float noiseFreq  = 3.2;

    // Listening: chaotic, fast
    if (mode > 0.5 && mode < 1.5) {
        noiseAmp   += 0.07;
        noiseSpeed += 0.70;
        noiseFreq   = 4.0;
    }
    // Thinking: slower rotation, smoother
    if (mode > 1.5 && mode < 2.5) {
        noiseSpeed = 1.1;
        noiseFreq  = 2.2;
        noiseAmp   = 0.09;
    }
    // Speaking: wave-rippled rim
    if (mode > 2.5) {
        noiseAmp   += 0.05;
        noiseSpeed += 0.40;
    }

    float2 rimUV = float2(
        cos(angle) * noiseFreq + time * noiseSpeed * 0.28,
        sin(angle) * noiseFreq + time * noiseSpeed * 0.21
    );
    float rim = fbm4(rimUV);

    // Breathing pulse in idle
    float breathe = (mode < 0.5) ? sin(time * 1.25) * 0.022 : 0.0;

    // Speaking: sinusoidal rim waves
    float speakWave = (mode > 2.5)
        ? (sin(angle * 7.0 + time * 5.5) * 0.04 + sin(angle * 13.0 + time * 8.0) * 0.02) * intensity
        : 0.0;

    // Thinking: slowly rotating wobble
    float thinkWobble = (mode > 1.5 && mode < 2.5)
        ? sin(angle * 3.0 + time * 1.8) * 0.04
        : 0.0;

    float orbR = 0.37 + rim * noiseAmp + breathe + speakWave + thinkWobble;

    // ── Interior color field ───────────────────────────────────────────────
    // Choose color pair based on mode, blended during transitions
    half3 cA, cB, cC;

    // Idle: indigo / violet
    half3 idleA = half3(0.20, 0.25, 1.00);
    half3 idleB = half3(0.60, 0.15, 0.90);
    half3 idleC = half3(0.10, 0.55, 1.00);

    // Listening: electric cyan / azure
    half3 lisA  = half3(0.00, 0.80, 1.00);
    half3 lisB  = half3(0.05, 0.35, 0.95);
    half3 lisC  = half3(0.45, 0.95, 1.00);

    // Thinking: amber / rose gold
    half3 thkA  = half3(1.00, 0.58, 0.05);
    half3 thkB  = half3(0.90, 0.18, 0.48);
    half3 thkC  = half3(1.00, 0.90, 0.25);

    // Speaking: emerald / teal
    half3 spkA  = half3(0.05, 0.90, 0.52);
    half3 spkB  = half3(0.00, 0.58, 0.82);
    half3 spkC  = half3(0.55, 1.00, 0.72);

    // Hard-select by mode (GPU-friendly integer compare via step)
    float m = clamp(mode, 0.0, 3.0);
    float isIdle = step(m, 0.4);
    float isLis  = step(0.5, m) * step(m, 1.4);
    float isThk  = step(1.5, m) * step(m, 2.4);
    float isSpk  = step(2.5, m);

    cA = idleA*half(isIdle) + lisA*half(isLis) + thkA*half(isThk) + spkA*half(isSpk);
    cB = idleB*half(isIdle) + lisB*half(isLis) + thkB*half(isThk) + spkB*half(isSpk);
    cC = idleC*half(isIdle) + lisC*half(isLis) + thkC*half(isThk) + spkC*half(isSpk);

    // Domain-warped FBM for interior pattern
    float2 q  = float2(fbm3(uv * 1.6 + time * 0.20),
                       fbm3(uv * 1.6 + float2(5.2, 1.3) + time * 0.17));
    float2 r  = float2(fbm3(uv * 1.4 + 4.0 * q + float2(1.7, 9.2) + time * 0.12),
                       fbm3(uv * 1.4 + 4.0 * q + float2(8.3, 2.8) + time * 0.09));
    float  fi = fbm3(uv * 0.9 + 4.0 * r);

    // Swirl speed up during thinking
    if (mode > 1.5 && mode < 2.5) {
        q += float2(fbm3(uv * 2.0 + time * 0.55), 0.0) * 0.3;
        fi = fbm3(uv + 2.0 * q + time * 0.3);
    }

    half3 interior = mix(mix(cA, cB, half(fi)), cC, half(fbm3(uv * 2.1 - time * 0.15) * 0.5));

    // Shimmer highlight near orb surface
    float shimmer = pow(clamp(fbm3(uv * 4.5 + time * 1.2), 0.0, 1.0), 2.5);
    interior += half3(shimmer * 0.55) * half(smoothstep(orbR - 0.18, orbR, dist));

    // ── Edge & glow ───────────────────────────────────────────────────────
    float orbEdge   = smoothstep(orbR + 0.022, orbR - 0.022, dist);

    // Rim glow: a bright band just outside the surface
    float rimGlow   = exp(-abs(dist - orbR) * 22.0) * 0.75;

    // Wide ambient halo
    float halo      = exp(-dist * 3.2) * 0.28;
    float outerHalo = exp(-(dist - orbR) * 6.5) * (1.0 - orbEdge) * 0.5;
    outerHalo       = max(outerHalo, 0.0);

    // Listening: frenetic outer sparkle ring
    float lisSparkle = 0.0;
    if (mode > 0.5 && mode < 1.5) {
        float sparkleAngle = fbm3(float2(angle * 2.5 + time * 2.0, dist * 8.0));
        lisSparkle = step(0.68, sparkleAngle)
                   * exp(-abs(dist - (orbR + 0.07)) * 30.0)
                   * intensity * 0.6;
    }

    // Thinking: slow rotating halo ring
    float thinkRing = 0.0;
    if (mode > 1.5 && mode < 2.5) {
        float ringR = orbR + 0.10;
        float ringW = 0.018;
        thinkRing   = exp(-abs(dist - ringR) / ringW) * 0.45
                    * (0.5 + 0.5 * sin(angle * 1.0 + time * 2.2));
    }

    // ── Composite ─────────────────────────────────────────────────────────
    half3 glowCol = mix(cA, cC, half(0.5 + 0.5 * sin(time * 0.75)));

    half3 rgb = interior    * half(orbEdge)
              + glowCol     * half(rimGlow)
              + glowCol     * half(halo * orbEdge)
              + glowCol     * half(outerHalo)
              + cC          * half(lisSparkle)
              + cC          * half(thinkRing);

    float a = clamp(orbEdge + rimGlow * 0.9 + outerHalo * 0.7 + lisSparkle + thinkRing, 0.0, 1.0);

    return half4(rgb, half(a));
}

// ─── Background Aurora ────────────────────────────────────────────────────────
//
//  A full-canvas aurora/glow that slowly shifts with mode color

[[ stitchable ]] half4 auroraBackground(
    float2 position,
    half4  inColor,
    float2 size,
    float  time,
    float  mode,
    float  intensity
) {
    float2 uv = position / size;

    float n1 = fbm4(float2(uv.x * 1.8 + time * 0.07, uv.y * 2.2 + time * 0.05));
    float n2 = fbm4(float2(uv.x * 1.2 - time * 0.06, uv.y * 1.6 + time * 0.08) + 3.7);
    float band = smoothstep(0.30, 0.70, uv.y);
    float aurora = n1 * n2 * band * (0.35 + intensity * 0.25);

    half3 cA, cB;
    float m = clamp(mode, 0.0, 3.0);
    float isIdle = step(m, 0.4);
    float isLis  = step(0.5, m) * step(m, 1.4);
    float isThk  = step(1.5, m) * step(m, 2.4);
    float isSpk  = step(2.5, m);

    half3 idA = half3(0.08, 0.06, 0.28); half3 idB = half3(0.18, 0.04, 0.22);
    half3 liA = half3(0.00, 0.14, 0.30); half3 liB = half3(0.04, 0.10, 0.28);
    half3 tkA = half3(0.28, 0.12, 0.04); half3 tkB = half3(0.22, 0.06, 0.14);
    half3 spA = half3(0.02, 0.20, 0.12); half3 spB = half3(0.00, 0.14, 0.22);

    cA = idA*half(isIdle) + liA*half(isLis) + tkA*half(isThk) + spA*half(isSpk);
    cB = idB*half(isIdle) + liB*half(isLis) + tkB*half(isThk) + spB*half(isSpk);

    half3 col = mix(cA, cB, half(n1));
    col *= half(aurora);

    return half4(col, half(aurora * 0.6));
}
