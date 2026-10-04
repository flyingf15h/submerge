#version 440
// One step of a damped wave equation on a height field. R = height now, G = height last step.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 texel;
    float damping;
    float simAspect;   // texture width / height in world units
    vec4 drop0;        // x, y (uv), radius (uv of height), strength
    vec4 drop1;
    vec4 drop2;
    vec4 drop3;
};
layout(binding = 1) uniform sampler2D prev;

float drop(vec4 d, vec2 uv) {
    if (d.w == 0.0) return 0.0;
    vec2 q = (uv - d.xy) * vec2(simAspect, 1.0);
    return d.w * exp(-dot(q, q) / (d.z * d.z));
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 c = texture(prev, uv);
    float n = texture(prev, uv + vec2(texel.x, 0)).r + texture(prev, uv - vec2(texel.x, 0)).r
            + texture(prev, uv + vec2(0, texel.y)).r + texture(prev, uv - vec2(0, texel.y)).r;
    float h = (n * 0.5 - c.g) * damping;
    h += drop(drop0, uv) + drop(drop1, uv) + drop(drop2, uv) + drop(drop3, uv);
    // soak up waves at the edges so they don't bounce off the edge of the simulated area
    vec2 edge = min(uv, 1.0 - uv);
    h *= smoothstep(0.0, 0.04, min(edge.x, edge.y));
    fragColor = vec4(h, c.r, 0.0, 1.0);
}
