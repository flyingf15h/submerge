#version 120
// Bends a straight koi sprite with a travelling wave so it swims smoothly instead of swapping frames.
attribute vec4 qt_Vertex;
attribute vec2 qt_MultiTexCoord0;
varying vec2 qt_TexCoord0;
uniform mat4 qt_Matrix;
uniform float qt_Opacity;
uniform float phase;    // swim cycle, radians
uniform float amp;      // tail swing in item pixels
uniform float bend;     // how far the body curves when turning, radians (at the tail)
uniform float headV;    // texture v of the head (anchor)
uniform float tailV;    // texture v of the tail tip
uniform float fog;      // how much the water haze covers it
uniform float pivotX;   // body centreline, item pixels
uniform float itemH;    // item height in pixels
uniform vec4 tint;      // rgb to recolour toward, a = how much (used for coloured shadows)
uniform float glitchy;  // 1 = shadow coloured in uneven cyan/magenta/blue bands
uniform float bodyHalf; // half the body's width, item pixels; anything wider is fin
uniform float flow;     // 0 = neat, 1 = tail and fins streaming out and rippling
uniform float fold;     // fins swept back (+) while driving, spread forward (-) while gliding
uniform float finTurn;  // turning: one pectoral fin spreads to brake while the other tucks in
void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    float w = clamp((qt_MultiTexCoord0.y - headV) / (tailV - headV), 0.0, 1.0);
    // a travelling wave runs down the whole body, about one S along its length: the head
    // barely recoils, the middle sways a little and the tail the most
    float waveK = 5.2 + flow * 0.9;
    float env = 0.1 + 0.9 * pow(w, 1.6);
    float swing = sin(phase - w * waveK) * env - sin(phase) * 0.1;
    // the tail fin lags behind the body and keeps whipping after each stroke, more so when the
    // fins are flowing, with a fine ripple running out along them
    float tailFin = smoothstep(0.78, 1.0, w);
    swing += tailFin * (0.2 + 0.4 * flow) * sin(phase - w * waveK - 1.2);
    swing += tailFin * flow * 0.12 * sin(phase * 2.0 - w * 12.0);
    vec4 p = qt_Vertex;
    p.x += amp * swing;
    // fins: whatever sticks out past the body sweeps back or spreads out and flutters, each
    // side a little out of step with the other
    float dx = qt_Vertex.x - pivotX;
    float side = dx < 0.0 ? -1.0 : 1.0;
    float reach = max(abs(dx) - bodyHalf, 0.0);
    float flutter = (0.08 + 0.22 * flow) * sin(phase * 0.5 - w * 3.0 + side * 1.3);
    float sweep = (fold * 0.6 + side * finTurn * 0.35) * (1.0 - 0.5 * tailFin) + flutter;
    p.y += reach * sweep;
    p.x -= side * reach * abs(sweep) * 0.25;    // a fin swept back also folds in toward the body
    // turning: the body curves along a smooth arc that starts just behind the head, so a turning
    // fish makes a soft C shape instead of folding at one joint. Each point keeps its distance
    // from the spine and rides the arc, so the sprite never shears or kinks.
    float startV = headV + (tailV - headV) * 0.08;
    float sigma = p.y - startV * itemH;             // distance along the spine past the arc start
    if (sigma > 0.0) {
        float k = bend / ((tailV - startV) * itemH); // constant curvature, reaching bend at the tail
        float th = k * sigma;
        float dx = p.x - pivotX;
        vec2 c = abs(k) > 1e-5 ? vec2(cos(th) - 1.0, sin(th)) / k : vec2(0.0, sigma);
        p.xy = vec2(pivotX, startV * itemH) + c + dx * vec2(cos(th), sin(th));
    }
    gl_Position = qt_Matrix * p;
}
