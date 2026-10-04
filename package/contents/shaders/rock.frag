#version 120
// A rounded rock sitting on the floor, lit from the surface.
varying vec2 qt_TexCoord0;
uniform mat4 qt_Matrix;
uniform float qt_Opacity;
uniform float seed;
uniform float fog;
uniform vec4 tint;
const vec3 FOG = vec3(0.012, 0.045, 0.16);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
void main() {
    // dome whose flat base sits near the bottom of the item
    vec2 q = (qt_TexCoord0 - vec2(0.5, 0.88)) / vec2(0.48, 0.84);
    float ang = atan(q.y, q.x);
    float r = 0.86 + 0.1 * noise(vec2(ang * 1.7 + seed * 9.0, seed)) + 0.04 * noise(vec2(ang * 6.0, seed + 4.0));
    float d = length(q);
    float a = smoothstep(r, r - 0.05, d) * smoothstep(0.12, 0.0, q.y);
    // light from above: bright crown, dark underside where it meets the gravel
    vec3 nrm = normalize(vec3(q.x, q.y, sqrt(max(0.0, 1.0 - min(1.0, d * d)))));
    float lit = clamp(dot(nrm, normalize(vec3(-0.25, -0.9, 0.45))), 0.0, 1.0);
    float grain = 0.75 + 0.5 * noise(qt_TexCoord0 * vec2(26.0, 16.0) + seed * 3.0);
    vec3 c = tint.rgb * (0.18 + 0.95 * lit) * grain;
    c += vec3(0.3, 0.55, 1.0) * pow(lit, 6.0) * 0.35;                 // caustic glint on the crown
    c *= mix(0.45, 1.0, smoothstep(0.1, -0.25, q.y));                 // contact shadow
    c = mix(c, FOG, fog);
    gl_FragColor = vec4(c * a, a) * qt_Opacity;
}
