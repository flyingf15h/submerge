#version 120
// Late-night PS2 loading screen grade: chromatic fringing, crushed blacks, grain, faint scanlines.
varying vec2 qt_TexCoord0;
uniform mat4 qt_Matrix;
uniform float qt_Opacity;
uniform float time;
uniform float grain;
uniform float aberration;
uniform float scanlines;
uniform vec2 res;
uniform sampler2D source;

float hash(vec2 p) {
    p = fract(p * vec2(443.897, 441.423));
    p += dot(p, p.yx + 19.19);
    return fract((p.x + p.y) * p.x);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 c = uv - 0.5;
    float r2 = dot(c, c);
    vec2 off = c * r2 * aberration;
    vec4 g = texture2D(source, uv);
    vec3 col = vec3(texture2D(source, uv + off).r, g.g, texture2D(source, uv - off).b);

    // crush the blacks and push the mids a little toward electric blue
    col = max(col - 0.018, 0.0) * 1.05;
    col = mix(col, smoothstep(0.0, 1.0, col), 0.35);
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    col += vec3(-0.01, 0.0, 0.03) * (1.0 - lum);
    // the water is a little more saturated in some places than others: soft regions drift
    // around and the whole amount swells and fades slowly. 1.25 is the floor; it only goes up
    // a little from there, and only in the blue water, so the fish keep their colours
    vec2 a = uv * vec2(res.x / max(res.y, 1.0), 1.0);
    float field = 0.5 + 0.3 * sin(a.x * 2.3 + time * 0.05 + sin(a.y * 1.9 + time * 0.03) * 1.5)
                      + 0.2 * sin(a.y * 3.1 - time * 0.04 + sin(a.x * 1.4 - time * 0.02) * 1.2);
    float swell = 0.55 + 0.45 * sin(time * 0.06 + 1.3 * sin(time * 0.017));
    float water = smoothstep(0.02, 0.12, col.b - max(col.r, col.g));
    float sat = 1.25 + 0.22 * smoothstep(0.25, 0.85, field) * swell * water;
    col = max(mix(vec3(lum), col, sat), 0.0);


    // scanlines and animated grain, strongest in the darks like film
    col *= 1.0 - scanlines * (0.5 + 0.5 * sin(uv.y * res.y * 1.5708));
    float n = hash(floor(uv * res / 1.5) + fract(time * 7.3) * 113.0) - 0.5;
    col += n * grain * (1.1 - lum);

    col *= 1.0 - r2 * 0.85;
    gl_FragColor = vec4(col, 1.0) * qt_Opacity;
}
