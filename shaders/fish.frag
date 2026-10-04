#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;
    float amp;
    float bend;
    float headV;
    float tailV;
    float fog;
    float pivotX;
    float itemH;
    vec4 tint;
    float glitchy;
};
layout(binding = 1) uniform sampler2D source;
void main() {
    vec4 c = texture(source, qt_TexCoord0);
    c.rgb = mix(c.rgb, tint.rgb * c.a, tint.a);
    if (glitchy > 0.0) {
        // uneven colour across the shadow: wavy cyan-to-magenta bands with a few blue blocks
        vec2 uv = qt_TexCoord0;
        float band = sin(uv.y * 55.0 + sin(uv.x * 9.0) * 2.0) * 0.5 + 0.5;
        float block = step(0.62, fract(sin(floor(uv.y * 24.0) * 91.7) * 4375.5));
        vec3 g = mix(vec3(0.1, 0.85, 1.0), vec3(1.0, 0.2, 0.85), band);
        g = mix(g, vec3(0.25, 0.3, 1.0), block * 0.6);
        c.rgb = mix(c.rgb, g * c.a, glitchy);
    }
    c.rgb = mix(c.rgb, vec3(0.012, 0.045, 0.16) * c.a, fog);
    fragColor = c * qt_Opacity;
}
