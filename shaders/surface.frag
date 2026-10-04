#version 440
// Light coming through the rippling surface, strongest along the top of the screen where the
// tank lights are: a moving network of bright caustic lines that fades out further down.
// Drawn additively (alpha 0), inside the refracted floor so the real ripples bend it too.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float aspect;
    float strength;
};

float caustic(vec2 p, float t) {
    vec2 q = mod(p * 6.2831, 6.2831) - 250.0;
    vec2 i = q;
    float c = 1.0;
    for (int n = 0; n < 4; n++) {
        float tt = t * (1.0 - 3.5 / float(n + 1));
        i = q + vec2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
        c += 1.0 / length(vec2(q.x / (sin(i.x + tt) / 0.005), q.y / (cos(i.y + tt) / 0.005)));
    }
    c /= 4.0;
    c = 1.17 - pow(c, 1.4);
    return pow(abs(c), 7.0);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = vec2(uv.x * aspect, uv.y);
    // stretch the pattern sideways near the top, like looking toward the lit end of the tank
    vec2 q = vec2(p.x * (0.55 + uv.y * 0.6), p.y * 1.3);
    float c = caustic(q * 0.9 + vec2(time * 0.012, 0.0), time * 0.42)
            + 0.6 * caustic(q * 1.7 + vec2(3.0, time * 0.01), time * 0.33 + 1.7);
    float band = pow(smoothstep(0.26, 0.0, uv.y), 1.8);
    // soft lamp glow hugging the very top edge
    float lamp = exp(-uv.y * 14.0) * (0.75 + 0.25 * sin(uv.x * 7.0 + time * 0.3));
    vec3 col = vec3(0.45, 0.75, 1.0) * c * band * 0.55 + vec3(0.35, 0.6, 1.0) * lamp * 0.35;
    fragColor = vec4(col * strength, 0.0) * qt_Opacity;
}
