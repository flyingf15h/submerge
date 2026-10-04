#version 120
varying vec2 qt_TexCoord0;
uniform mat4 qt_Matrix;
uniform float qt_Opacity;
uniform float phase;
uniform float amp;
uniform float bend;
uniform float headV;
uniform float tailV;
uniform float fog;
uniform float pivotX;
uniform float itemH;
uniform vec4 tint;
uniform float glitchy;
uniform sampler2D source;
void main() {
    vec4 c = texture2D(source, qt_TexCoord0);
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
    gl_FragColor = c * qt_Opacity;
}
