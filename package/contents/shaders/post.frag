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
    col = max(mix(vec3(lum), col, 1.25), 0.0);

    // scanlines and animated grain, strongest in the darks like film
    col *= 1.0 - scanlines * (0.5 + 0.5 * sin(uv.y * res.y * 1.5708));
    float n = hash(floor(uv * res / 1.5) + fract(time * 7.3) * 113.0) - 0.5;
    col += n * grain * (1.1 - lum);

    col *= 1.0 - r2 * 0.85;
    gl_FragColor = vec4(col, 1.0) * qt_Opacity;
}
