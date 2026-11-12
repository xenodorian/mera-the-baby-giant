shader_type canvas_item;
// CRT look for pixel art, one pass.
// Source: "How to make pixel art look like it's on a CRT"
//   https://www.spritecook.ai/blog/crt-shader-pixel-art
//   SpriteCook, 10 November 2026.
// This is the article's Godot variant (shader_type canvas_item, the shared
// body from LUMA_BLUR through crt(), and fragment() writing crt(UV, FRAGCOORD)).
// The article states no explicit license.
//
// Sampling is adapted for this project: the game is drawn at 5x into a 1080p
// window (native game resolution 384x216). The `game` uniform is the screen
// texture, and each 5x5 screen block is treated as one game pixel, sampled at
// its centre. HUD and menus sit on higher CanvasLayers and stay unfiltered.
// On Android, `cheap` shrinks the glow loop to 3x3.

uniform sampler2D game : hint_screen_texture, filter_nearest, repeat_disable;
uniform bool cheap = false; // Android: 3x3 glow instead of 5x5

const int PIXEL_SCALE = 5;

// Settings. Distances are in game pixels unless they say otherwise.
const float LUMA_BLUR = 0.45;      // how soft brightness edges get
const float CHROMA_BLUR = 1.2;     // color bleeds further than brightness, like NTSC
const float BEAM_MIN = 0.21;       // scanline thickness on black, in lines
const float BEAM_MAX = 0.40;       // ...and on white: bright lines fatten until they touch
const float MASK_PX = 2.0;         // screen pixels per phosphor stripe
const float MASK_DARK = 0.62;      // the two phosphor colors that are off
const float MASK_LIGHT = 1.22;     // and the one that is on
const float GLOW = 0.26;           // light spilling around bright things
const float BOOST = 1.5;           // wins back what the gaps and the mask take
const vec2 WARP = vec2(0.031, 0.041);  // screen curvature, 0 for a flat screen

// NTSC brightness (Y) and color (I, Q). Columns, so RGB_TO_YIQ * rgb gives yiq.
const mat3 RGB_TO_YIQ = mat3(vec3(0.299, 0.596, 0.211), vec3(0.587, -0.274, -0.523), vec3(0.114, -0.322, 0.312));
const mat3 YIQ_TO_RGB = mat3(vec3(1.0, 1.0, 1.0), vec3(0.956, -0.272, -1.106), vec3(0.621, -0.647, 1.703));

vec3 game_px(ivec2 p) {
    ivec2 tex = textureSize(game, 0);
    ivec2 gsize = max(tex / PIXEL_SCALE, ivec2(1));
    p = clamp(p, ivec2(0), gsize - 1);
    vec2 uv = (vec2(p) + 0.5) * float(PIXEL_SCALE) / vec2(tex);
    return textureLod(game, uv, 0.0).rgb;
}

// 1. The signal. One row of the game, blurred sideways only, read at x.
// Brightness first goes through a [1 2 1] filter, which wipes out anything that flips every pixel:
// that's what melts 1-pixel dither into one flat color. Color gets a wider blur.
vec3 signal(int row, float x) {
    int x0 = int(floor(x));
    vec3 t[9];
    for (int k = 0; k < 9; k++) {
        t[k] = RGB_TO_YIQ * game_px(ivec2(x0 - 4 + k, row));
    }
    vec3 sum = vec3(0.0);
    vec3 weight = vec3(0.0);
    for (int k = 1; k < 8; k++) {
        float luma = 0.25 * t[k - 1].x + 0.5 * t[k].x + 0.25 * t[k + 1].x;
        float d = float(x0 - 4 + k) + 0.5 - x;
        float wl = exp(-0.5 * d * d / (LUMA_BLUR * LUMA_BLUR));
        float wc = exp(-0.5 * d * d / (CHROMA_BLUR * CHROMA_BLUR));
        sum += vec3(luma * wl, t[k].y * wc, t[k].z * wc);
        weight += vec3(wl, wc, wc);
    }
    return clamp(YIQ_TO_RGB * (sum / weight), 0.0, 1.0);
}

// 2. The beam. Each row lights a soft band whose thickness grows with brightness.
vec3 beam(vec3 lin, float dist) {
    vec3 sigma = mix(vec3(BEAM_MIN), vec3(BEAM_MAX), pow(lin, vec3(0.6)));
    return lin * exp(-0.5 * dist * dist / (sigma * sigma));
}

// 4. Glow: a wide soft blur of the game, added on top.
vec3 glow(vec2 p) {
    ivec2 c = ivec2(floor(p));
    vec3 sum = vec3(0.0);
    float weight = 0.0;
    int r = cheap ? 1 : 2;
    for (int j = -2; j <= 2; j++) {
        for (int i = -2; i <= 2; i++) {
            if (abs(i) > r || abs(j) > r) {
                continue;
            }
            vec2 d = vec2(c + ivec2(i, j)) + 0.5 - p;
            float w = exp(-0.5 * dot(d, d) / 2.56);
            sum += w * pow(game_px(c + ivec2(i, j)), vec3(2.4));
            weight += w;
        }
    }
    return sum / max(weight, 0.0001);
}

// uv: 0..1 across the screen, top-left origin. screen_px: this pixel's position on screen.
vec3 crt(vec2 uv, vec2 screen_px) {
    // 5. Curvature: bend the coordinates first, black outside the glass.
    vec2 c = uv * 2.0 - 1.0;
    c *= vec2(1.0 + c.y * c.y * WARP.x, 1.0 + c.x * c.x * WARP.y);
    uv = c * 0.5 + 0.5;
    if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
        return vec3(0.0);
    }
    vec2 p = uv * vec2(textureSize(game, 0)) / float(PIXEL_SCALE);    // position in game pixels
    float y = p.y - 0.5;
    int r0 = int(floor(y));
    vec3 col = vec3(0.0);
    for (int k = 0; k < 2; k++) {                  // the two nearest rows
        vec3 lin = pow(signal(r0 + k, p.x), vec3(2.4));
        col += beam(lin, y - float(r0 + k));
    }
    col *= 1.32;
    // 3. Phosphor mask, aperture grille: red, green and blue stripes on the glass.
    int stripe = int(mod(floor(screen_px.x / MASK_PX), 3.0));
    vec3 on = vec3(float(stripe == 0), float(stripe == 1), float(stripe == 2));
    col *= mix(vec3(MASK_DARK), vec3(MASK_LIGHT), on);
    col += GLOW * glow(p);
    col *= 1.0 - 0.22 * pow(clamp(dot(c, c) * 0.5, 0.0, 1.0), 1.5);   // darker towards the edges
    return pow(clamp(col * BOOST, 0.0, 1.0), vec3(1.0 / 2.2));
}

void fragment() {
    COLOR = vec4(crt(UV, FRAGCOORD.xy), 1.0);
}
