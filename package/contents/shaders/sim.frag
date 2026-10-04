#version 120
// One step of a damped wave equation on a height field. R = height now, G = height last step.
varying vec2 qt_TexCoord0;
uniform mat4 qt_Matrix;
uniform float qt_Opacity;
uniform vec2 texel;
uniform float damping;
uniform float simAspect;   // texture width / height in world units
uniform vec4 drop0;        // x, y (uv), radius (uv of height), strength
uniform vec4 drop1;
uniform vec4 drop2;
uniform vec4 drop3;
uniform sampler2D prev;

float drop(vec4 d, vec2 uv) {
    if (d.w == 0.0) return 0.0;
    vec2 q = (uv - d.xy) * vec2(simAspect, 1.0);
    return d.w * exp(-dot(q, q) / (d.z * d.z));
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 c = texture2D(prev, uv);
    float n = texture2D(prev, uv + vec2(texel.x, 0)).r + texture2D(prev, uv - vec2(texel.x, 0)).r
            + texture2D(prev, uv + vec2(0, texel.y)).r + texture2D(prev, uv - vec2(0, texel.y)).r;
    float h = (n * 0.5 - c.g) * damping;
    h += drop(drop0, uv) + drop(drop1, uv) + drop(drop2, uv) + drop(drop3, uv);
    // soak up waves at the edges so they don't bounce off the edge of the simulated area
    vec2 edge = min(uv, 1.0 - uv);
    h *= smoothstep(0.0, 0.04, min(edge.x, edge.y));
    gl_FragColor = vec4(h, c.r, 0.0, 1.0);
}
