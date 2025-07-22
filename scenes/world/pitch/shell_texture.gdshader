shader_type spatial;

uniform int shell_index : hint_range(0, 10) = 0;
uniform int num_shells : hint_range(1, 10) = 10;
uniform vec2 grass_grid_size = vec2(10.0, 10.0);
uniform float density : hint_range(0.0, 1.0) = 0.8;
uniform vec3 grass_color : source_color = vec3(0.2, 0.7, 0.3);
uniform float grass_length : hint_range(0.01, 1.0) = 0.1;
uniform float big_noise_period = 30.0;

uniform sampler2D pitch_texture : source_color, hint_default_white;


varying vec3 world_position;
varying vec3 world_normal;

/*
void vertex() {
    // Extrude vertices along normal for shell layering
    float shell_height = float(shell_index) / float(num_shells);
    VERTEX += NORMAL * grass_length * shell_height;
    
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
*/


float random(vec2 input) {
    return fract(sin(dot(input, vec2(12.9898, 78.233))) * 43758.5453);
}

float hash(vec2 p) {
    p = fract(p * vec2(0.1031, 0.1030));
    p += dot(p, p.yx + 19.19);
    return fract((p.x + p.y) * p.x);
}


float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    // Smooth interpolation
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    // Four corners of the grid cell
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    // Bilinear interpolation
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}



void fragment() {
    vec2 grid_uv = UV * grass_grid_size;
    int x = int(floor(grid_uv.x));
    int y = int(floor(grid_uv.y));
    
    vec2 input = vec2(float(x), float(y));

    float big_random = noise(input / big_noise_period);
    float random = random(input)*0.7 + big_random*0.3;
    
    // grass strand height (0 to num_shells)
    int height = int(floor(random * float(num_shells + 1) * density));
    
    // Taper grass as they get higher
    float shell_ratio = float(shell_index) / float(num_shells);

    vec4 pitch_color = texture(pitch_texture, UV);
    bool is_line = length(pitch_color.xyz) < 0.5;
    
    if (height < shell_index) {
        discard;
    } else {
        // Color variation based on height and add some randomness
        float color_variation = 0.8 + 0.4 * random;
        vec3 final_color;
        if (is_line) {
            final_color = vec3(1,1,1) * color_variation;
        } else {
            final_color = grass_color * color_variation;
        }

        // Darken higher shells slightly for depth
        final_color *= (0.2 + shell_ratio);
        
        ALBEDO = final_color;
        ALPHA = 1.0 - shell_ratio * 0.5; // Fade out higher shells
    }
}
