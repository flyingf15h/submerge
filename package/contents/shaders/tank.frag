#version 120
// The tank seen through the front glass: the water surface from below along the top,
// the pebble floor receding into fog along the bottom, the back of the tank in between.
varying vec2 qt_TexCoord0;
uniform mat4 qt_Matrix;
uniform float qt_Opacity;
uniform float time;
uniform float aspect;     // width / height
uniform float hy;         // horizon, fraction of height
uniform float eye;        // camera height, fraction of tank height
uniform float focal;      // screen heights per world unit at depth 1
uniform float depthK;     // depth = 1 + depthK * Z
uniform float simHalfX;   // ripple sim covers X in [-simHalfX, simHalfX], Z in [0, 1]
uniform float rays;       // light shaft strength
uniform vec2 simTexel;
uniform sampler2D sim;

const vec3 FOG = vec3(0.012, 0.045, 0.16);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 hash2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
    float s = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { s += a * noise(p); p = p * 2.03 + 17.1; a *= 0.5; }
    return s;
}

vec2 simUV(vec2 xz) { return vec2(xz.x / (2.0 * simHalfX) + 0.5, xz.y); }
float simH(vec2 uv) {
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return 0.0;
    return texture2D(sim, uv).r;
}

// classic tileable water caustic (iterated sine warp)
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

// gravel: round stones of varied size sitting in sand, from a jittered grid
vec3 gravel(vec2 p, float lod) {
    vec2 ip = floor(p), fp = fract(p);
    vec3 col = vec3(0.0);
    float cover = 0.0;
    for (int y = -1; y <= 1; y++)
    for (int x = -1; x <= 1; x++) {
        vec2 id = ip + vec2(x, y);
        vec2 c = vec2(x, y) + hash2(id) * 0.6 + 0.2;
        float rad = 0.38 + 0.3 * hash(id + 5.7);
        vec2 q = (fp - c) / vec2(rad, rad * (0.75 + 0.25 * hash(id + 1.3)));
        float d = length(q);
        float m = smoothstep(1.0, 0.82, d);
        if (m > cover) {
            float r = hash(id);
            vec3 base = mix(vec3(0.32, 0.33, 0.36), vec3(0.62, 0.58, 0.52), r);
            base = mix(base, vec3(0.2, 0.22, 0.27), step(0.82, hash(id + 2.2)));
            float lit = clamp(0.55 - q.y * 0.45 - q.x * 0.15, 0.0, 1.0) * (1.0 - d * d * 0.5);
            col = base * (0.35 + 0.85 * lit);
            cover = m;
        }
    }
    vec3 sand = vec3(0.2, 0.2, 0.21) * (0.7 + 0.5 * noise(p * 3.1));
    col = mix(sand * 0.6, col, cover);
    return mix(col, vec3(0.26, 0.26, 0.28), lod);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float sx = (uv.x - 0.5) * aspect;   // screen x in screen-height units, 0 at centre
    float sy = uv.y;
    float t = time;

    float surfFarY = hy - focal * (1.0 - eye) / (1.0 + depthK);
    float floorFarY = hy + focal * eye / (1.0 + depthK);
    vec3 col;
    float wallMix = 0.0;

    if (sy > floorFarY) {
        // ---- floor ----
        float depth = focal * eye / (sy - hy);
        float Z = (depth - 1.0) / depthK;
        float X = sx * depth / focal;
        vec2 P = vec2(X, Z * depthK);

        vec2 pp = P * 34.0;
        float lod = clamp(length(fwidth(pp)) * 1.2 - 0.25, 0.0, 1.0);
        col = gravel(pp, lod);
        // a sprinkling of bigger stones
        vec2 pb = P * 11.0;
        float lodb = clamp(length(fwidth(pb)) * 1.2 - 0.25, 0.0, 1.0);
        vec3 big = gravel(pb + 31.0, lodb);
        col = mix(col, big, step(0.72, hash(floor(pb + 31.0))) * 0.9 * (1.0 - lodb));
        // a few bigger flat stones and darker patches of silt
        float silt = fbm(P * 2.5);
        col *= mix(0.6, 1.15, smoothstep(0.3, 0.7, silt));
        col = mix(col, vec3(0.16, 0.18, 0.2), smoothstep(0.62, 0.75, fbm(P * 1.3 + 9.0)) * 0.6);

        // caustics from the surface, plus bright focused rings where real ripples pass overhead
        float c = caustic(P * 0.55 + vec2(0.0, t * 0.01), t * 0.35);
        c += 0.6 * caustic(P * 0.9 + 3.3, t * 0.27 + 2.0);
        vec2 suv = simUV(vec2(X, Z));
        float h0 = simH(suv);
        float lap = simH(suv + vec2(simTexel.x, 0)) + simH(suv - vec2(simTexel.x, 0))
                  + simH(suv + vec2(0, simTexel.y)) + simH(suv - vec2(0, simTexel.y)) - 4.0 * h0;
        c += clamp(-lap * 28.0, -0.4, 1.2);
        col *= vec3(0.42, 0.6, 1.0);
        col += vec3(0.35, 0.65, 1.0) * c * (1.0 - lod * 0.6) * 0.55;

        float fog = smoothstep(0.0, 1.0, Z);
        col = mix(col, FOG, 0.25 + 0.7 * fog);
        // floor right against the glass falls into shadow
        col *= mix(0.55, 1.0, smoothstep(1.05, 0.75, sy));
    } else if (sy < surfFarY) {
        // ---- surface, seen from underneath ----
        float depth = focal * (1.0 - eye) / (hy - sy);
        float Z = (depth - 1.0) / depthK;
        float X = sx * depth / focal;
        vec2 P = vec2(X, Z * depthK);

        // swell: a few travelling waves plus noise, and the ripple sim on top
        float e = 0.02;
        vec2 suv = simUV(vec2(X, Z));
        float sh = simH(suv);
        float gx = (simH(suv + vec2(simTexel.x, 0)) - simH(suv - vec2(simTexel.x, 0))) * 6.0;
        float gz = (simH(suv + vec2(0, simTexel.y)) - simH(suv - vec2(0, simTexel.y))) * 6.0;
        vec2 grad = vec2(gx, gz);
        for (int k = 0; k < 4; k++) {
            float a = float(k) * 1.7 + 0.4;
            vec2 d = vec2(cos(a), sin(a));
            float f = 3.0 + float(k) * 2.3;
            grad += d * cos(dot(P, d) * f + t * (0.9 + 0.35 * float(k))) * (0.16 / (1.0 + float(k)));
        }
        grad += (vec2(noise(P * 5.0 + vec2(t * 0.3, 0)), noise(P * 5.0 + vec2(0, t * 0.25) + 7.0)) - 0.5) * 0.5;

        // total internal reflection: mostly a dark mirror of the tank, with bright streaks
        // where the surface tilts toward the light above
        float tilt = dot(grad, normalize(vec2(0.3, -1.0)));
        float streak = pow(clamp(0.5 + tilt * 1.6, 0.0, 1.0), 7.0);
        float window = smoothstep(0.8, 0.0, Z);          // looking up steeply lets light through
        col = mix(vec3(0.02, 0.09, 0.28), vec3(0.08, 0.30, 0.75), window * 0.55 + 0.15);
        col += vec3(0.55, 0.85, 1.0) * streak * (0.35 + window * 0.9);
        col += vec3(0.7, 0.9, 1.0) * pow(clamp(0.5 + tilt * 2.2, 0.0, 1.0), 18.0) * 0.6;
        vec2 wp = P * 0.9 + grad * 0.06;
        float net = caustic(wp, t * 0.5) + 0.5 * caustic(wp * 1.9 + 4.0, t * 0.4);
        col += vec3(0.5, 0.8, 1.0) * net * (0.25 + window * 0.6) * (1.0 - smoothstep(0.4, 1.0, Z));
        col = mix(col, FOG * 1.6, smoothstep(0.35, 1.0, Z) * 0.85);
        // the bright line where the surface meets the back glass
        col += vec3(0.35, 0.6, 1.0) * exp(-abs(sy - surfFarY) * 160.0) * 0.6;
    } else {
        // ---- back of the tank: deep water haze with faint plant silhouettes ----
        float h = eye - (sy - hy) * (1.0 + depthK) / focal;
        float X = sx * (1.0 + depthK) / focal;
        col = mix(FOG * 0.7, FOG * 1.7, smoothstep(0.0, 1.0, h));
        float weeds = smoothstep(0.55, 0.75, fbm(vec2(X * 6.0 + sin(h * 3.0 + t * 0.3) * 0.15, h * 0.6)))
                    * smoothstep(0.9, 0.1, h);
        col *= 1.0 - weeds * 0.45;
        col += vec3(0.2, 0.4, 0.9) * caustic(vec2(X, h) * 0.7, t * 0.3) * 0.06 * h;
        col += vec3(0.25, 0.5, 1.0) * exp(-abs(sy - floorFarY) * 120.0) * 0.08;
        wallMix = 1.0;
    }

    // light shafts slanting down from the surface
    if (sy > surfFarY - 0.02) {
        float a = sx + (sy - surfFarY) * 0.45;
        float r = noise(vec2(a * 9.0, t * 0.08)) * noise(vec2(a * 23.0 + 3.0, t * 0.13 + 4.0));
        r = smoothstep(0.12, 0.6, r);
        float fade = exp(-(sy - surfFarY) * 2.6);
        col += vec3(0.25, 0.5, 1.0) * r * fade * rays * 0.35;
    }

    gl_FragColor = vec4(col, 1.0) * qt_Opacity;
}
