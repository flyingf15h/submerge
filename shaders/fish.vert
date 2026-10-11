#version 440
// Bends a straight koi sprite with a travelling wave so it swims smoothly instead of swapping frames.
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;    // swim cycle, radians
    float amp;      // tail swing in item pixels
    float bend;     // how far the back half folds when turning, radians
    float headV;    // texture v of the head (anchor)
    float tailV;    // texture v of the tail tip
    float fog;      // how much the water haze covers it
    float pivotX;   // body centreline, item pixels
    float itemH;    // item height in pixels
    vec4 tint;      // rgb to recolour toward, a = how much (used for coloured shadows)
    float glitchy;  // 1 = shadow coloured in uneven cyan/magenta/blue bands
};
out gl_PerVertex { vec4 gl_Position; };
void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    float w = clamp((qt_MultiTexCoord0.y - headV) / (tailV - headV), 0.0, 1.0);
    // a travelling wave runs down the whole body: the head barely moves, the middle sways a
    // little and the tail the most, with about one S along the length
    float env = 0.12 + 0.88 * pow(w, 1.4);
    float swing = sin(phase - w * 4.4) * env - sin(phase) * 0.12;
    vec4 p = qt_Vertex;
    p.x += amp * swing;
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
