shader_type canvas_item;

// ============================================
// 色差偏移后处理效果 (Chromatic Aberration Post-Processing)
// ============================================
// 使用方法：
// 1. 创建一个覆盖全屏的 ColorRect 或 TextureRect
// 2. 为其创建 ShaderMaterial 并赋予此 shader
// 3. 调整参数以获得理想的色差偏移效果

// --- 色差偏移参数 ---
// 色差偏移强度（0 = 无色差）
uniform float chromatic_aberration : hint_range(0.0, 10.0, 0.1) = 1.0;

// --- 屏幕纹理（Godot 4.x 标准写法） ---
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel_size = SCREEN_PIXEL_SIZE;

	// --- 色差偏移 ---
	float aberration_offset = chromatic_aberration * pixel_size.x;
	float r = texture(SCREEN_TEXTURE, uv + vec2(aberration_offset, 0.0)).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv - vec2(aberration_offset, 0.0)).b;
	vec3 color = vec3(r, g, b);

	COLOR = vec4(color, 1.0);
}
