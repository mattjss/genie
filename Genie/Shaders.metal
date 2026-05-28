#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// ─── Noise Primitives ─────────────────────────────────────────────────────────

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
        mix(hash21(i),              hash21(i + float2(1,0)), u.x),
        mix(hash21(i + float2(0,1)), hash21(i + float2(1,1)), u.x),
        u.y);
}

// Rotation-scaled FBM — avoids grid alignment artifacts
static float fbm(float2 p, int oct) {
    float v = 0.0, a = 0.55;
    // 2x scale + ~37° rotation each octave
    float2x2 rot = float2x2(1.6, 1.2, -1.2, 1.6);
    for (int i = 0; i < oct; i++) {
        v += a * vnoise(p);
        p  = rot * p;
        a *= 0.48;
    }
    return v;
}

// ─── Voice Wave ───────────────────────────────────────────────────────────────
//
//  Full-screen horizontal glowing wave bar.
//  mode  :  0 = idle, 1 = listening, 2 = thinking/processing, 3 = speaking
//  intensity : 0..1 audio activity

[[ stitchable ]] half4 voiceWave(
    float2 position,
    half4  inColor,
    float2 size,
    float  time,
    float  mode,
    float  intensity
) {
    float2 uv = position / size;    // (0,0) top-left → (1,1) bottom-right
    float  x  = uv.x;               // 0..1
    float  y  = uv.y;               // 0..1
    float  cx = x - 0.5;            // −0.5..+0.5 (centred)

    // ── Wave vertical position, animated per mode ──────────────────────────

    float baseY = 0.68;
    float waveY;

    if (mode < 0.5) {
        // Idle: near-still, barely breathing
        float n = vnoise(float2(x * 2.2 + time * 0.10, time * 0.07));
        waveY = baseY + (n - 0.5) * 0.007;

    } else if (mode < 1.5) {
        // Listening: organic inward-flowing noise
        float n1 = fbm(float2(x * 3.8 + time * 0.80, time * 0.24), 4);
        float n2 = fbm(float2(x * 5.8 - time * 1.05, time * 0.33 + 4.1), 3);
        waveY = baseY + (n1 - 0.5) * 0.024 + (n2 - 0.5) * 0.013;

    } else if (mode < 2.5) {
        // Thinking: slow sinusoidal sweep + drift
        float n = fbm(float2(x * 2.1 + time * 0.42, time * 0.18), 3);
        waveY = baseY
              + sin(x * 6.2831 + time * 2.0) * 0.017
              + (n - 0.5) * 0.010;

    } else {
        // Speaking: rhythmic pulses radiating outward from centre
        float pulse = sin(abs(cx) * 24.0 - time * 5.8) * 0.021 * exp(-abs(cx) * 4.5)
                    + sin(abs(cx) * 13.0 - time * 4.2) * 0.011;
        float n = fbm(float2(x * 3.2 + time * 0.55, time * 0.20), 3);
        waveY = baseY + pulse + (n - 0.5) * 0.008;
    }

    float dy = y - waveY;   // signed distance from wave centre line

    // ── Horizontal profile: bright centre, fades gently toward edges ───────

    float edgeFade = 1.0 - smoothstep(0.40, 0.52, abs(cx));
    float hProf    = pow(edgeFade, 0.42);   // hold brightness wide before dropping off

    // ── Brightness layers ───────────────────────────────────────────────────

    // 1. Hair-thin core line (main "wire")
    float coreW = 0.0025 + intensity * 0.0022;
    float core  = exp(-dy * dy / (coreW * coreW * 0.45));

    // 2. Soft inner glow band (a few percent of screen height above & below)
    float inner = exp(-abs(dy) * 170.0) * 0.55;

    // 3. Wide ambient halo (lens flare depth effect — denser under line)
    float outer = exp(-abs(dy) * 52.0) * exp(-cx * cx * 3.5) * 0.32;

    // 4. Bright centre hotspot (the cyan focal point at x=0.5)
    float hotspot = exp(-(cx * cx * 58.0 + dy * dy * 10000.0));

    // 5. Flowing horizontal streaks (wind/shimmer along the wave)
    float streakN = fbm(float2(x * 9.5 + time * 2.0, baseY * 3.5 + time * 0.09), 3);
    float streaks = pow(max(streakN - 0.44, 0.0), 1.7) * core * 1.6;

    // 6. Secondary "wing" lobes either side of hotspot (gives lens-eye shape)
    float wingL = exp(-(cx + 0.20)*(cx + 0.20) * 24.0 - dy*dy * 1400.0) * 0.38;
    float wingR = exp(-(cx - 0.20)*(cx - 0.20) * 24.0 - dy*dy * 1400.0) * 0.38;

    float B = (core + inner + outer + hotspot + streaks + wingL + wingR) * hProf;

    // Idle: very dim
    B *= (mode < 0.5) ? 0.22 : 1.0;

    // ── Colour palette per mode ─────────────────────────────────────────────

    half3 cHot, cMid, cAmbient;

    if (mode < 0.5) {
        // Idle — dim blue-white
        cHot     = half3(0.65, 0.82, 1.00);
        cMid     = half3(0.10, 0.24, 0.72);
        cAmbient = half3(0.02, 0.04, 0.18);

    } else if (mode < 1.5) {
        // Listening — electric cyan (matches reference screenshot)
        cHot     = half3(0.48, 1.00, 0.96);
        cMid     = half3(0.04, 0.50, 0.84);
        cAmbient = half3(0.01, 0.08, 0.24);

    } else if (mode < 2.5) {
        // Thinking / Processing — amber-gold
        cHot     = half3(1.00, 0.90, 0.40);
        cMid     = half3(0.80, 0.28, 0.06);
        cAmbient = half3(0.14, 0.04, 0.01);

    } else {
        // Speaking — emerald-teal
        cHot     = half3(0.36, 1.00, 0.66);
        cMid     = half3(0.04, 0.60, 0.50);
        cAmbient = half3(0.01, 0.10, 0.09);
    }

    // Three-tier brightness → colour ramp
    float b1 = clamp(B * 1.0, 0.0, 1.0);
    float b2 = clamp(B * 2.8, 0.0, 1.0);
    float b3 = clamp(B * 7.0, 0.0, 1.0);

    half3 col = cAmbient;
    col = mix(col, cMid,  half(b1));
    col = mix(col, cHot,  half(b2));
    // Hotspot centre: push toward white-bright
    col = mix(col, cHot * half(1.25), half(b3 * hotspot * hProf));

    float alpha = clamp(B * 1.6, 0.0, 1.0);
    return half4(col, half(alpha));
}
