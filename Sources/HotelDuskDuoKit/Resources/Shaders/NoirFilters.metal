#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Generate pseudo-random noise for vintage 1979 film grain
static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Noir Film Grain & Monochrome Shader
[[stitchable]] half4 noirFilmGrain(float2 position, half4 color, float time, float intensity) {
    // 1. Convert to noir luminance (monochrome)
    half lum = dot(color.rgb, half3(0.299, 0.587, 0.114));

    // 2. High-contrast noir curve with slight sepia tint
    half3 noirColor = half3(lum * 1.05h, lum * 0.98h, lum * 0.88h);

    // 3. Dynamic procedural film grain
    float noise = hash21(position + float2(sin(time * 12.0) * 100.0, cos(time * 12.0) * 100.0));
    half grain = half(noise - 0.5) * half(intensity);

    // 4. Subtle corner vignette
    // Normalized position assuming typical screen coords
    half3 finalColor = clamp(noirColor + grain, 0.0h, 1.0h);

    return half4(finalColor, color.a);
}

// Rotoscoped pencil edge accentuation shader
[[stitchable]] half4 pencilSketchTone(float2 position, half4 color, float contrast) {
    half lum = dot(color.rgb, half3(0.299, 0.587, 0.114));
    // Posterize slightly to mimic hand-drawn rotoscope animation cells
    half steps = 6.0h;
    half posterized = floor(lum * steps) / steps;
    // Boost contrast
    half finalLum = clamp((posterized - 0.5h) * half(contrast) + 0.5h, 0.0h, 1.0h);
    return half4(half3(finalLum), color.a);
}
