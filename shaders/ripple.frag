#version 440
// Real ripples on the pond: a height field from sim.frag bends the view of the floor underneath
// (refraction) and focuses light into bright moving rings (caustics), like light through a real surface.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 simTexel;
    float refraction;
    float glow;
};
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D sim;

void main() {
    vec2 uv = qt_TexCoord0;
    float h = texture(sim, uv).r;
    float hl = texture(sim, uv - vec2(simTexel.x, 0)).r, hr = texture(sim, uv + vec2(simTexel.x, 0)).r;
    float hu = texture(sim, uv - vec2(0, simTexel.y)).r, hd = texture(sim, uv + vec2(0, simTexel.y)).r;
    vec2 grad = vec2(hr - hl, hd - hu);
    float lap = hl + hr + hu + hd - 4.0 * h;

    vec4 c = texture(source, uv + grad * refraction);
    // converging parts of a wave act like a lens and brighten the floor; troughs dim it slightly
    float focus = clamp(-lap * 11.0, -0.08, 0.4);
    c.rgb += vec3(0.38, 0.66, 1.0) * focus * glow * (0.25 + c.rgb);
    // a faint glint on the wave faces themselves
    c.rgb += vec3(0.6, 0.8, 1.0) * clamp(dot(grad, vec2(-0.6, -0.8)) * 3.0, 0.0, 0.07) * glow;
    fragColor = c * qt_Opacity;
}
