#version 120
// One to three steps of a damped wave equation on a height field. R = height now, G = height last
// step. The simulation runs at 60 steps a second; with the frame rate capped at 30 or 20 each
// update does two or three steps at once so the ripples keep the same speed.
varying vec2 qt_TexCoord0;
uniform mat4 qt_Matrix;
uniform float qt_Opacity;
uniform vec2 texel;
uniform float damping;
uniform float simAspect;   // texture width / height in world units
uniform float steps;       // how many steps to advance: 1, 2 or 3
uniform vec4 drop0;        // x, y (uv), radius (uv of height), strength
uniform vec4 drop1;
uniform vec4 drop2;
uniform vec4 drop3;
uniform sampler2D prev;

float drop(vec4 d, vec2 uv) {
    if (d.w == 0.0) return 0.0;
    vec2 q = (uv - d.xy) * vec2(simAspect, 1.0);
    float r = max(d.z, 1.2 * texel.y);   // at least a texel wide on the coarse grid
    return d.w * exp(-dot(q, q) / (r * r));
}

// soak up waves at the edges so they don't bounce off the edge of the simulated area
float edge(vec2 uv) {
    vec2 e = min(uv, 1.0 - uv);
    return smoothstep(0.0, 0.04, min(e.x, e.y));
}

// the first step at uv, from the stored state; new drops land here
float step1(vec2 uv) {
    float n = texture2D(prev, uv + vec2(texel.x, 0)).r + texture2D(prev, uv - vec2(texel.x, 0)).r
            + texture2D(prev, uv + vec2(0, texel.y)).r + texture2D(prev, uv - vec2(0, texel.y)).r;
    float h = (n * 0.5 - texture2D(prev, uv).g) * damping;
    h += drop(drop0, uv) + drop(drop1, uv) + drop(drop2, uv) + drop(drop3, uv);
    return h * edge(uv);
}

// the second step at uv
float step2(vec2 uv) {
    float n = step1(uv + vec2(texel.x, 0)) + step1(uv - vec2(texel.x, 0))
            + step1(uv + vec2(0, texel.y)) + step1(uv - vec2(0, texel.y));
    return (n * 0.5 - texture2D(prev, uv).r) * damping * edge(uv);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float h1 = step1(uv);
    if (steps < 1.5) {
        gl_FragColor = vec4(h1, texture2D(prev, uv).r, 0.0, 1.0);
        return;
    }
    float h2 = step2(uv);
    if (steps < 2.5) {
        gl_FragColor = vec4(h2, h1, 0.0, 1.0);
        return;
    }
    float n = step2(uv + vec2(texel.x, 0)) + step2(uv - vec2(texel.x, 0))
            + step2(uv + vec2(0, texel.y)) + step2(uv - vec2(0, texel.y));
    float h3 = (n * 0.5 - h1) * damping;
    gl_FragColor = vec4(h3 * edge(uv), h2, 0.0, 1.0);
}
