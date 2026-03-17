shader_type canvas_item;

// ============================================
// 场景过渡后处理效果 (Transition Post-Processing)
// ============================================
// 使用方法：
// 1. 创建一个覆盖全屏的 ColorRect 或 TextureRect
// 2. 为其创建 ShaderMaterial 并赋予此 shader
// 3. 为 transition_texture 指定一张灰度渐变图（不同的图产生不同的过渡效果）
// 4. 通过 Tween 控制 progress 参数从 0 → 1 实现渐入，1 → 0 实现渐出
//
// 灰度图示例效果：
// - 径向渐变图 → 圆形擦除
// - 水平渐变图 → 左→右擦除
// - 菱形渐变图 → 菱形过渡
// - 噪声图 → 像素溶解效果

// 覆盖纹理（过渡完成后显示的图片，默认黑色；如需纯色过渡，指定一张纯色纹理即可）
uniform sampler2D cover_texture : hint_default_black;
// --- 过渡遮罩纹理（灰度图） ---
uniform sampler2D transition_texture : hint_default_white;

// --- 过渡参数 ---
// 过渡进度：0.0 = 完全显示原画面，1.0 = 完全被覆盖色填满
uniform float progress : hint_range(0.0, 1.0, 0.01) = 0.0;
// 过渡边缘柔和度：值越大，过渡边缘越柔和
uniform float smoothness : hint_range(0.0, 0.5, 0.01) = 0.05;
// 过渡边缘颜色（设置 alpha > 0 启用边缘发光效果）
uniform vec4 edge_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
// 边缘宽度
uniform float edge_width : hint_range(0.0, 0.2, 0.01) = 0.03;
// 是否反转过渡方向
uniform float invert : hint_range(0.0, 1.0, 1.0) = 0.0;

// --- 屏幕纹理（Godot 4.x 标准写法） ---
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;

	// --- 采样屏幕颜色 ---
	vec3 screen_color = texture(SCREEN_TEXTURE, uv).rgb;

	// --- 采样覆盖纹理 ---
	vec3 cover = texture(cover_texture, uv).rgb;

	// --- 采样过渡遮罩（取灰度值） ---
	float mask = texture(transition_texture, uv).r;

	// 是否反转
	mask = mix(mask, 1.0 - mask, invert);

	// --- 计算过渡 ---
	// 将 progress 映射到 [-smoothness, 1.0 + smoothness] 范围，确保完整过渡
	float adjusted_progress = progress * (1.0 + smoothness * 2.0) - smoothness;

	// 使用 smoothstep 实现柔和过渡边缘
	float alpha = smoothstep(adjusted_progress - smoothness, adjusted_progress + smoothness, mask);
	// alpha: 1.0 = 显示原画面, 0.0 = 显示覆盖色

	// --- 边缘发光效果 ---
	vec3 final_color;
	if (edge_color.a > 0.01 && edge_width > 0.001) {
		// 计算边缘区域：在过渡边界附近的窄带
		float edge_inner = smoothstep(adjusted_progress - smoothness - edge_width, adjusted_progress - smoothness, mask);
		float edge_outer = smoothstep(adjusted_progress + smoothness, adjusted_progress + smoothness + edge_width, mask);
		float edge_factor = edge_inner * (1.0 - edge_outer);

		// 混合：原画面 ← 边缘色 ← 覆盖色/覆盖纹理
		vec3 base_mix = mix(cover, screen_color, alpha);
		final_color = mix(base_mix, edge_color.rgb, edge_factor * edge_color.a);
	} else {
		// 无边缘效果，直接混合
		final_color = mix(cover, screen_color, alpha);
	}

	// --- 输出 ---
	COLOR = vec4(final_color, 1.0);
}
