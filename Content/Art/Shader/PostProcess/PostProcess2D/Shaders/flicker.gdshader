shader_type canvas_item;

// ============================================
// 闪烁后处理效果 (Flicker Post-Processing)
// ============================================
// 使用方法：
// 1. 创建一个覆盖全屏的 ColorRect 或 TextureRect
// 2. 为其创建 ShaderMaterial 并赋予此 shader
// 3. 调整参数以获得理想的屏幕闪烁效果

// --- 闪烁参数 ---
// 屏幕整体闪烁强度
uniform float flicker_strength : hint_range(0.0, 0.2, 0.001) = 0.02;
// 闪烁速度
uniform float flicker_speed : hint_range(0.0, 30.0, 0.1) = 8.0;

// --- 屏幕纹理（Godot 4.x 标准写法） ---
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;

	// --- 采样屏幕颜色 ---
	vec3 color = texture(SCREEN_TEXTURE, uv).rgb;

	// --- 闪烁 ---
	float flicker = 1.0 + flicker_strength * sin(TIME * flicker_speed * 6.2832);
	color *= flicker;

	COLOR = vec4(color, 1.0);
}
