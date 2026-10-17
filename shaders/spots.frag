#version 440
// Occasional patches of sun and shade drifting through the water, like clouds passing over a
// pond. Each patch slowly swells in, wanders, and fades away again. Both are kept faint: a sun
// patch partly covers the blue with gold (adding yellow on top of blue would only wash it out to
// grey) and a shade patch darkens what's below. They get the same glitch treatment as the blurry
// foreground fish: a slight RGB split, faint scanlines, and now and then bands jumping sideways.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float aspect;
};

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

// all the patches at one point: gold light in rgb, sun coverage in a, shade written to shade
vec4 patches(vec2 p, out float shade) {
    vec3 light = vec3(0.0);
    float sun = 0.0;
    shade = 0.0;
    for (int i = 0; i < 8; i++) {
        float f = float(i);
        float seed = f * 2.399;
        // most of the time a patch is gone; it only shows during the top of its slow cycle
        float life = pow(max(0.0, sin(time * (0.021 + f * 0.004) + seed * 3.1)), 3.0);
        if (life < 0.002) continue;
        vec2 c = vec2(aspect * (0.5 + 0.45 * sin(time * (0.011 + f * 0.002) + seed * 5.0)),
                      0.5 + 0.42 * cos(time * (0.009 + f * 0.0017) + seed * 7.0));
        vec2 d = p - c;
        // lumpy edge so they read as dappled light rather than perfect circles
        float a = atan(d.y, d.x);
        float r = (0.22 + 0.09 * fract(seed * 1.7)) * (1.0 + 0.14 * sin(a * 2.0 + time * 0.06 + seed)
                                                          + 0.05 * sin(a * 5.0 - time * 0.05 + seed * 2.0));
        float m = exp(-dot(d, d) / (r * r)) * life;
        if (mod(f, 2.0) > 0.5) {  // odd patches are shade (no int % in GLSL ES 1.00)
            shade += m;
        } else {
            vec3 gold = mix(vec3(1.0, 0.74, 0.26), vec3(1.0, 0.85, 0.45), fract(seed));
            sun += m * m;
            light += gold * (m * m + m * 0.1);
        }
    }
    return vec4(light, sun);
}

void main() {
    vec2 uv = qt_TexCoord0;
    // short glitch bursts at random moments: a few horizontal bands jump sideways
    float tick = floor(time * 9.0);
    float burst = step(0.95, hash(tick));
    float band = floor(uv.y * 18.0);
    // the patches are soft, so the bands have to jump a long way for the tear to show
    uv.x += (hash(band + tick * 13.0) - 0.5) * 0.09 * burst * step(0.6, hash(band * 3.1 + tick));

    // the colour channels sit slightly apart, more so during a burst
    float split = (0.008 + 0.012 * burst) * aspect;
    vec2 p = vec2(uv.x * aspect, uv.y);
    float sh, shR, shB;
    vec4 g = patches(p, sh);
    vec4 rs = patches(p + vec2(split, 0.0), shR);
    vec4 bs = patches(p - vec2(split, 0.0), shB);
    vec3 light = vec3(rs.r, g.g, bs.b);
    float sun = max(g.a, max(rs.a, bs.a));
    float shade = max(sh, max(shR, shB));

    float scan = 0.85 + 0.15 * sin(uv.y * 900.0 + time * 6.0);
    light *= scan;
    light += vec3(0.0, 0.05, 0.12) * sun * burst;   // cold flash while glitching
    fragColor = vec4(light * 0.2, clamp(sun * 0.16 + shade * 0.12 * scan, 0.0, 0.3)) * qt_Opacity;
}
