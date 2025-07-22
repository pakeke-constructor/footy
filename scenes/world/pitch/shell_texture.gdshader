shader_type spatial;

uniform int shell_index : hint_range(0, 10) = 0;
uniform int max_shells : hint_range(1, 10) = 10;
uniform vec2 grass_grid_size = vec2(10.0, 10.0);
uniform float density : hint_range(0.0, 1.0) = 0.8;
uniform vec3 grass_color : source_color = vec3(0.2, 0.7, 0.3);
uniform float grass_length : hint_range(0.01, 1.0) = 0.1;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
    // Extrude vertices along normal for shell layering
    float shell_height = float(shell_index) / float(max_shells);
    VERTEX += NORMAL * grass_length * shell_height;
    
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    vec2 grid_uv = UV * grass_grid_size;
    int x = int(floor(grid_uv.x));
    int y = int(floor(grid_uv.y));
    
    float r2 = fract(sin(dot(vec2(float(x/8), float(y/8)), vec2(12.9898, 78.233))) * 43758.5453);

    // Create pseudo-random height based on grid position
    float random = fract(sin(dot(vec2(float(x), float(y)), vec2(12.9898, 78.233))) * 43758.5453);
    
    // grass strand height (0 to max_shells)
    int height = int(floor(random * float(max_shells + 1) * density));
    
    // Taper grass as they get higher
    float shell_ratio = float(shell_index) / float(max_shells);
    
    if (height < shell_index) {
        discard;
    } else {
        // Color variation based on height and add some randomness
        float darken_variation = 0.8 + 0.4 * r2;
        float color_variation = 0.8 + 0.4 * random;
        vec3 final_color = grass_color * color_variation * darken_variation;
        
        // Darken higher shells slightly for depth
        final_color *= (1.0 - shell_ratio * 0.3);
        
        ALBEDO = final_color;
        ALPHA = 1.0 - shell_ratio * 0.5; // Fade out higher shells
    }
}