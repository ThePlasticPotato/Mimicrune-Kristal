local Shaders = {}

Shaders["GradientH"] = love.graphics.newShader([[
    extern vec3 from;
    extern vec3 to;
    extern number scale;
    vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
    {
        vec4 froma = vec4(from.r, from.g, from.b, 1);
        vec4 toa = vec4(to.r, to.g, to.b, 1);
        return Texel(tex, texture_coords) * (froma + (toa - froma) * mod(texture_coords.x / scale, 1.0)) * color;
    }
]])

Shaders["GradientV"] = love.graphics.newShader([[
    extern vec3 from;
    extern vec3 to;
    extern number scale;
    vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
    {
        vec4 froma = vec4(from.r, from.g, from.b, 1);
        vec4 toa = vec4(to.r, to.g, to.b, 1);
        return Texel(tex, texture_coords) * (froma + (toa - froma) * mod(texture_coords.y / scale, 1.0)) * color;
    }
]])

Shaders["GradientH"]:send("scale", 1)
Shaders["GradientV"]:send("scale", 1)

Shaders["DynGradient"] = love.graphics.newShader([[
    extern Image colors;
    extern vec2 colorSize;

    vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
    {
        float cx = texture_coords.x * (colorSize.x - 1.0) + 0.5;
        float cy = texture_coords.y * (colorSize.y - 1.0) + 0.5;

        float from_x = (max(0.0, floor(cx - 0.5)) + 0.5) / colorSize.x;
        float to_x = from_x + 1.0 / colorSize.x;

        float from_y = (max(0.0, floor(cy - 1.0)) + 0.5) / colorSize.y;
        float to_y = from_y + 1.0 / colorSize.y;

        vec4 color_upper = mix(Texel(colors, vec2(from_x, from_y)), Texel(colors, vec2(to_x, from_y)), cx - (from_x * colorSize.x));
        vec4 color_lower = mix(Texel(colors, vec2(from_x, to_y)), Texel(colors, vec2(to_x, to_y)), cx - (from_x * colorSize.x));

        return Texel(tex, texture_coords) * mix(color_upper, color_lower, cy - (from_y * colorSize.y)) * color;
    }
]])

Shaders["AngleGradient"] = love.graphics.newShader([[
    extern vec4 from;
    extern vec4 to;
    extern float amount;
    extern float angle;
    extern vec4 bounds;

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
    {
        vec2 origin = vec2(0.5, 0.5);

        vec2 uv = (texture_coords - bounds.xy) / bounds.zw - origin;

        float gradAngle = -angle + atan(uv.y, uv.x);

        float len = length(uv);
        uv = vec2(cos(gradAngle) * len, sin(gradAngle) * len) + origin;

        vec4 tex_color = Texel(tex, texture_coords);
        vec4 grad_color = mix(from, to, smoothstep(0.0, 1.0, uv.x)) * tex_color.a;
        return mix(tex_color, grad_color, amount);
    }
]])

Shaders["White"] = love.graphics.newShader([[
    extern float whiteAmount;

    vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
    {
        vec4 outputcolor = Texel(tex, texture_coords) * color;
        outputcolor.rgb += (vec3(1, 1, 1) - outputcolor.rgb) * whiteAmount;
        return outputcolor;
    }
]])

Shaders["AddColor"] = love.graphics.newShader([[
    extern vec3 inputcolor;
    extern float amount;

    vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
    {
        vec4 outputcolor = Texel(tex, texture_coords) * color;
        outputcolor.rgb += (inputcolor.rgb - outputcolor.rgb) * amount;
        return outputcolor;
    }
]])

Shaders["Grayscale"] = love.graphics.newShader([[
    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
    {
        vec4 outputcolor = Texel(tex, texture_coords) * color;
        float luma = dot(outputcolor.rgb, vec3(0.299, 0.587, 0.114));
        return vec4(vec3(luma), outputcolor.a);
    }
]])

Shaders["GonerPalette"] = love.graphics.newShader([[
    extern vec3 shadow;
    extern vec3 mid;
    extern vec3 light;
    extern float amount;
    extern float steps;

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
    {
        vec4 base = Texel(tex, texture_coords) * color;
        float luma = dot(base.rgb, vec3(0.299, 0.587, 0.114));
        float step_count = max(steps, 1.0);
        float stepped = floor(luma * step_count + 0.5) / step_count;

        vec3 low_mid = mix(shadow, mid, smoothstep(0.0, 0.55, stepped));
        vec3 high_mid = mix(mid, light, smoothstep(0.35, 1.0, stepped));
        vec3 mapped = mix(low_mid, high_mid, smoothstep(0.45, 0.65, stepped));

        base.rgb = mix(base.rgb, mapped, amount);
        return base;
    }
]])

Shaders["GonerPalette"]:send("shadow", {0.13, 0.13, 0.16})
Shaders["GonerPalette"]:send("mid", {0.53, 0.53, 0.60})
Shaders["GonerPalette"]:send("light", {0.84, 0.84, 0.90})
Shaders["GonerPalette"]:send("amount", 1)
Shaders["GonerPalette"]:send("steps", 4)

Shaders["Mask"] = love.graphics.newShader[[
    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
        if (Texel(tex, texture_coords).a == 0.0) {
            // a discarded pixel wont be applied as the stencil.
            discard;
        }
        return vec4(1.0);
    }
 ]]

Shaders["HeightDepth"] = love.graphics.newShader[[
#pragma language glsl3
    extern number depth_mode;
    extern number anchor_y;
    extern number face_ground_y;
    extern number face_top_y;
    extern number height_pixels;
    extern number depth_scale;
    extern number depth_bias;
    extern number alpha_threshold;

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
        vec4 pixel = Texel(tex, texture_coords) * color;
        if (pixel.a <= alpha_threshold) {
            discard;
        }

        float view_depth;
        if (depth_mode < 0.5) {
            // screen_y = ground_y - pixel_height, so this reconstructs
            // ground_y + pixel_height.
            view_depth = 2.0 * anchor_y - screen_coords.y;
        } else if (depth_mode > 1.5) {
            // Flat effects such as ground shadows follow the horizontal plane
            // for their entire footprint, including pixels below the anchor.
            view_depth = screen_coords.y + 2.0 * height_pixels;
        } else if (screen_coords.y <= face_top_y) {
            // Pixels above the face boundary lie on the horizontal top plane
            view_depth = screen_coords.y + 2.0 * height_pixels;
        } else {
            // Pixels below it lie on the vertical face at a constant ground Y
            view_depth = 2.0 * face_ground_y - screen_coords.y;
        }

        gl_FragDepth = clamp(depth_bias + view_depth * depth_scale, 0.0, 1.0);
        return pixel;
    }
]]

Shaders["UnderwaterDepth"] = love.graphics.newShader[[
    extern Image background_texture;
    extern vec2 screen_size;
    extern vec2 map_size;
    extern number time;
    extern number motion_speed;
    extern number opacity;
    extern number void_strength;
    extern number pixel_size;
    extern number pattern_scale;
    extern number distortion;
    extern number particle_strength;
    extern vec3 shallow_color;
    extern vec3 deep_color;

    float hash21(vec2 point) {
        point = fract(point * vec2(123.34, 456.21));
        point += dot(point, point + 45.32);
        return fract(point.x * point.y);
    }

    float valueNoise(vec2 point) {
        vec2 cell = floor(point);
        vec2 local = fract(point);
        local = local * local * (3.0 - 2.0 * local);
        float bottom = mix(
            hash21(cell),
            hash21(cell + vec2(1.0, 0.0)),
            local.x
        );
        float top = mix(
            hash21(cell + vec2(0.0, 1.0)),
            hash21(cell + vec2(1.0, 1.0)),
            local.x
        );
        return mix(bottom, top, local.y);
    }

    float layeredNoise(vec2 point) {
        float result = valueNoise(point) * 0.58;
        result += valueNoise(point * 2.03 + 17.4) * 0.27;
        result += valueNoise(point * 4.11 - 8.7) * 0.15;
        return result;
    }

    float volumetricMurk(vec2 point, float clock) {
        vec2 slow_drift = vec2(clock * 0.031, -clock * 0.019);
        float broad = layeredNoise(point * 0.0023 + slow_drift);
        float folded = layeredNoise(
            vec2(point.x * 0.0038, point.y * 0.0051)
                + vec2(-clock * 0.024, clock * 0.014) + broad * 1.7
        );
        float distant = valueNoise(
            point * 0.0011 + vec2(clock * 0.009, clock * 0.006) + 31.0
        );
        return clamp(broad * 0.48 + folded * 0.34 + distant * 0.18,
            0.0, 1.0);
    }

    float marineSnow(
        vec2 point,
        float clock,
        float cell_size,
        float threshold,
        float seed,
        float fall_speed
    ) {
        vec2 moving = point + vec2(
            clock * (1.0 + seed * 0.11)
                + sin(point.y * 0.035 + clock * 0.73 + seed) * 2.0,
            -clock * fall_speed
        );
        vec2 cell = floor(moving / cell_size);
        vec2 local = fract(moving / cell_size) * cell_size;
        vec2 center = vec2(
            0.14 + hash21(cell + seed) * 0.72,
            0.14 + hash21(cell + seed + 7.1) * 0.72
        ) * cell_size;
        float radius = 0.65
            + hash21(cell + seed + 12.4) * 0.35;
        float mote = 1.0 - step(radius, length(local - center));
        return mote * step(threshold, hash21(cell + seed + 19.3));
    }

    vec4 effect(
        vec4 color,
        Image texture,
        vec2 texture_coords,
        vec2 screen_coords
    ) {
        vec2 map_position = texture_coords * map_size;
        vec2 pixel_position =
            floor(map_position / pixel_size) * pixel_size;
        vec2 scaled_position = pixel_position / pattern_scale;
        float clock = time * motion_speed;
        float vertical_depth = clamp(
            pixel_position.y / max(map_size.y, 1.0), 0.0, 1.0);

        float murk = volumetricMurk(scaled_position, clock);
        float absorption = clamp(
            0.18 + vertical_depth * 0.58 + murk * 0.34, 0.0, 1.0);
        vec3 water = mix(shallow_color, deep_color, absorption);
        water = mix(water, deep_color, murk * 0.22);

        vec2 particle_position = floor(map_position) / pattern_scale;
        float snow_near = marineSnow(
            particle_position, clock, 31.0, 0.82, 2.4, 8.0);
        float snow_far = marineSnow(
            particle_position + 13.0, clock, 53.0, 0.89, 8.7, 4.5);
        float snow = (
            snow_near * 0.075 + snow_far * 0.04
        ) * particle_strength;
        snow *= mix(1.0, 0.48, vertical_depth);

        float dim_variation = layeredNoise(
            scaled_position * 0.006
                + vec2(-clock * 0.018, clock * 0.011) + 57.0
        );
        vec3 particulate_color = mix(
            shallow_color, vec3(0.12, 0.22, 0.27), 0.36);
        vec3 result = water
            + particulate_color * snow
            + shallow_color * (dim_variation - 0.5) * 0.07;

        float refraction_noise = layeredNoise(
            scaled_position * 0.006
                + vec2(clock * 0.12, -clock * 0.075) + 11.2
        );
        vec2 refraction_field = vec2(
            sin(
                scaled_position.y * 0.052 + clock * 1.13
                    + sin(scaled_position.x * 0.013 - clock * 0.37) * 1.35
            ),
            sin(
                scaled_position.x * 0.041 - clock * 0.86
                    + sin(scaled_position.y * 0.017 + clock * 0.29) * 1.1
            )
        );
        refraction_field *= mix(0.38, 1.0, refraction_noise);
        vec2 refraction_offset = floor(
            refraction_field * distortion + 0.5);
        vec2 background_coords = clamp(
            (screen_coords + refraction_offset)
                / max(screen_size, vec2(1.0)),
            vec2(0.0),
            vec2(1.0)
        );
        vec4 background = Texel(
            background_texture, background_coords);
        float background_energy = max(
            background.r, max(background.g, background.b));
        float artwork_presence = smoothstep(
            0.008, 0.11, background_energy);
        float atmosphere_strength = mix(
            void_strength, 1.0, artwork_presence);

        float density = mix(0.5, 1.0, smoothstep(0.25, 0.78, murk));
        float haze_alpha = opacity * atmosphere_strength * density;
        float composite_alpha = background.a
            + haze_alpha * (1.0 - background.a);
        vec3 composite_premultiplied =
            background.rgb * (1.0 - haze_alpha)
            + max(result, vec3(0.0)) * haze_alpha;
        vec3 composite = composite_alpha > 0.0001
            ? composite_premultiplied / composite_alpha
            : vec3(0.0);
        return vec4(composite, composite_alpha) * color;
    }
]]

Shaders["TerrainEdgeFog"] = love.graphics.newShader[[
    extern Image fog_texture;
    extern vec2 field_size;
    extern vec2 field_origin;
    extern vec2 fog_size;
    extern number fog_scale;
    extern number pixel_size;
    extern vec2 scroll;
    extern number time;
    extern number distance_limit;
    extern number extent;
    extern number wave_amplitude;
    extern number wave_length;
    extern number wave_speed;
    extern number opacity;

    vec4 effect(vec4 color, Image field, vec2 texture_coords, vec2 screen_coords) {
        vec4 field_pixel = Texel(field, texture_coords);
        if (field_pixel.r > 0.5 || field_pixel.g > 0.5) {
            discard;
        }

        vec2 world_position = field_origin + texture_coords * field_size;
        vec2 pixel_position =
            floor(world_position / pixel_size) * pixel_size;
        float phase = 6.28318530718 / max(wave_length, 1.0);
        float wave =
            sin((pixel_position.x + pixel_position.y * 0.43) * phase
                + time * wave_speed) * 0.48
            + sin((pixel_position.y - pixel_position.x * 0.31)
                * phase * 2.17 - time * wave_speed * 1.31 + 1.9) * 0.31
            + sin((pixel_position.x + pixel_position.y * 0.77)
                * phase * 3.73 + time * wave_speed * 0.59 + 4.2) * 0.21;
        float wavy_extent = max(
            floor((extent + wave * wave_amplitude) / pixel_size + 0.5)
                * pixel_size,
            pixel_size
        );
        float distance_from_surface =
            floor(field_pixel.a * distance_limit / pixel_size + 0.5)
                * pixel_size;
        float fade =
            clamp(1.0 - distance_from_surface / wavy_extent, 0.0, 1.0);
        fade = floor(fade * 6.0 + 0.5) / 6.0;
        if (fade <= 0.001) {
            discard;
        }

        vec2 fog_coords = fract(
            (pixel_position + scroll * time)
                / max(fog_size * fog_scale, vec2(1.0))
        );
        vec4 fog = Texel(fog_texture, fog_coords);
        return fog * color * vec4(1.0, 1.0, 1.0, opacity * fade);
    }
]]

return Shaders
