uniform Image lut_tex;
uniform float strength;

const float CELLS_PER_ROW = 8.0;
const float CELL_SIZE = 0.125;
const float HALF_TEXEL_SIZE = 0.000976562;
const float CELL_SIZE_FIXED = 0.123046875;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec4 base_col = Texel(texture, texture_coords);

    float blue_cell = base_col.b * (CELLS_PER_ROW * CELLS_PER_ROW - 1.0);

    vec2 lower_cell;
    vec2 lower_sample;
    vec2 upper_cell;
    vec2 upper_sample;

    lower_cell.y = floor(blue_cell / CELLS_PER_ROW);
    lower_cell.x = floor(blue_cell) - lower_cell.y * CELLS_PER_ROW;
    lower_sample.x = lower_cell.x * CELL_SIZE
        + HALF_TEXEL_SIZE
        + CELL_SIZE_FIXED * base_col.r;
    lower_sample.y = lower_cell.y * CELL_SIZE
        + HALF_TEXEL_SIZE
        + CELL_SIZE_FIXED * base_col.g;

    upper_cell.y = floor(ceil(blue_cell) / CELLS_PER_ROW);
    upper_cell.x = ceil(blue_cell) - upper_cell.y * CELLS_PER_ROW;
    upper_sample.x = upper_cell.x * CELL_SIZE
        + HALF_TEXEL_SIZE
        + CELL_SIZE_FIXED * base_col.r;
    upper_sample.y = upper_cell.y * CELL_SIZE
        + HALF_TEXEL_SIZE
        + CELL_SIZE_FIXED * base_col.g;

    vec3 out_col = mix(
        Texel(lut_tex, lower_sample).rgb,
        Texel(lut_tex, upper_sample).rgb,
        fract(blue_cell)
    );
    out_col = mix(base_col.rgb, out_col, strength);

    vec4 stored = Texel(texture, texture_coords);
    float alpha = stored.a;
    vec3 base_rgb = alpha > 0.0 ? stored.rgb / alpha : vec3(0.0);

    // Perform the LUT lookup using base_rgb instead of stored.rgb.

    return color * vec4(out_col * alpha, alpha);
}
