#version 440
// Digital-glitch treatment for the out-of-focus foreground fish: RGB channels drift apart,
// faint scanlines run through them, and every so often a few horizontal bands jump sideways.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float seed;
    float strength;
};
layout(binding = 1) uniform sampler2D source;

float hash(float n) { return fract(sin(n * 127.1 + seed * 31.7) * 43758.5453); }

void main() {
    vec2 uv = qt_TexCoord0;
    // short glitch bursts at random moments
    float tick = floor(time * 9.0);
    float burst = step(0.94, hash(tick)) * strength;
    float band = floor(uv.y * 26.0);
    float jump = (hash(band + tick * 13.0) - 0.5) * 0.018 * burst * step(0.7, hash(band * 3.1 + tick));
    uv.x += jump;

    // a constant slight split that widens during a burst
    float split = (0.0018 + 0.004 * burst + 0.0006 * sin(time * 1.3 + seed)) * strength;
    vec4 g = texture(source, uv);
    float r = texture(source, uv + vec2(split, 0.0)).r;
    float b = texture(source, uv - vec2(split, 0.0)).b;
    float a = max(g.a, max(texture(source, uv + vec2(split, 0.0)).a, texture(source, uv - vec2(split, 0.0)).a));
    vec3 col = vec3(r, g.g, b);
    col *= 0.94 + 0.06 * sin(uv.y * 900.0 + time * 6.0);   // scanlines
    col += vec3(0.0, 0.05, 0.12) * a * burst;                // cold flash while glitching
    fragColor = vec4(col, a) * qt_Opacity;
}
