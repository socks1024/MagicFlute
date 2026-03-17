shader_type canvas_item;

// ==================== 溶解着色器 ====================
// 使用噪声纹理驱动的溶解效果，适用于 2D 精灵/UI 等 CanvasItem 节点。
// 用法：将此 shader 设置为 Sprite2D/TextureRect 等节点的 Material，
//       通过调整 dissolve_amount 参数（0.0 ~ 1.0）来控制溶解进度。
// ==================================================

// 溶解噪声纹理（推荐使用 NoiseTexture2D 或自定义灰度噪声图）
uniform sampler2D dissolve_texture : hint_default_white;

// 溶解进度：0.0 = 完全显示，1.0 = 完全溶解
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;

// 溶解边缘发光颜色
uniform vec4 edge_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// 溶解边缘宽度（值越大，发光边缘越宽）
uniform float edge_width : hint_range(0.0, 0.2) = 0.05;

// 是否反转溶解方向（true 时从亮到暗溶解，false 时从暗到亮溶解）
uniform bool invert = false;

void fragment() {
	// 采样原始纹理颜色
	vec4 original_color = texture(TEXTURE, UV);

	// 采样噪声纹理，取红色通道作为溶解值
	float noise_value = texture(dissolve_texture, UV).r;

	// 根据反转设置调整噪声值
	if (invert) {
		noise_value = 1.0 - noise_value;
	}

	// 计算溶解阈值（将 dissolve_amount 映射到更大范围以确保完全溶解）
	float threshold = dissolve_amount * (1.0 + edge_width);

	// 当噪声值小于阈值时，该像素被溶解（丢弃）
	if (noise_value < threshold - edge_width) {
		discard;
	}

	// 计算边缘发光：在溶解边界附近的像素混合发光颜色
	float edge_factor = smoothstep(threshold - edge_width, threshold, noise_value);

	// 将边缘发光颜色与原始颜色混合
	vec3 final_rgb = mix(edge_color.rgb, original_color.rgb, edge_factor);
	float final_alpha = original_color.a;

	COLOR = vec4(final_rgb, final_alpha);
}
