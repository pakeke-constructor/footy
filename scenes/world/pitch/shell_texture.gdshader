
shader_type spatial;

uniform int shell_index : hint_range(0, 10) = 0;
uniform vec2 pitch_size = vec2(10,10);


void fragment() {
    int x = int((UV.x * pitch_size.x) / pitch_size.x);
    int y = int((UV.y * pitch_size.y) / pitch_size.y);

	...
    
	if (height > shell_index) {
		discard;
	} else {
		ALBEDO = vec3(...);		
	}
}

