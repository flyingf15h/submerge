#version 120
// Digital-glitch treatment for the out-of-focus foreground fish: RGB channels drift apart,
// faint scanlines run through them, and every so often a few horizontal bands jump sideways.
varying vec2 qt_TexCoord0;
uniform mat4 qt_Matrix;
uniform float qt_Opacity;
uniform float time;
uniform float seed;
uniform float strength;
uniform float saturation;
uniform sampler2D source;

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
    vec4 g = texture2D(source, uv);
    vec4 rs = texture2D(source, uv + vec2(split, 0.0));
    vec4 bs = texture2D(source, uv - vec2(split, 0.0));
    float a = max(g.a, max(rs.a, bs.a));
    vec3 col = vec3(rs.r, g.g, bs.b);
    col = max(mix(vec3(dot(col, vec3(0.299, 0.587, 0.114))), col, 1.0 + saturation), 0.0);
    col *= 0.94 + 0.06 * sin(uv.y * 900.0 + time * 6.0);   // scanlines
    col += vec3(0.0, 0.05, 0.12) * a * burst;                // cold flash while glitching
    gl_FragColor = vec4(col, a) * qt_Opacity;
}
