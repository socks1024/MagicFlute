shader_type canvas_item;

// ==================== 内轮廓线着色器 ====================
// 在精灵不透明区域的内侧边缘绘制描边效果，适用于 2D 精灵等 CanvasItem 节点。
// 原理：在片段着色器中采样周围像素的 alpha 值，如果当前像素不透明但
//       周围存在透明像素，则说明当前像素位于边缘内侧，用轮廓颜色替换。
// 优点：无需膨胀顶点，兼容 Sprite2D、TextureRect 等所有 CanvasItem 节点。
// 用法：将此 shader 设置为节点的 Material，
//       通过 enabled 参数控制开关，outline_width 控制描边粗细。
// ==================================================

// 是否启用轮廓线效果
uniform bool enabled = false;

// 轮廓线颜色
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// 轮廓线宽度（像素数，值越大描边越粗）
uniform float outline_width : hint_range(0.0, 10.0, 0.5) = 1.0;

// 判定边缘的 alpha 阈值（低于此值视为透明）
uniform float alpha_threshold : hint_range(0.0, 1.0, 0.01) = 0.5;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);

	if (!enabled) {
		COLOR = original_color;
	} else {
		float current_alpha = original_color.a;

		// 当前像素不透明时，检查是否处于边缘内侧
		if (current_alpha >= alpha_threshold) {
			vec2 pixel_size = TEXTURE_PIXEL_SIZE * outline_width;

			// 采样周围 8 个方向的像素 alpha 值
			float min_alpha = 1.0;
			min_alpha = min(min_alpha, texture(TEXTURE, UV + vec2(-pixel_size.x, 0.0)).a);   // 左
			min_alpha = min(min_alpha, texture(TEXTURE, UV + vec2(pixel_size.x, 0.0)).a);    // 右
			min_alpha = min(min_alpha, texture(TEXTURE, UV + vec2(0.0, -pixel_size.y)).a);   // 上
			min_alpha = min(min_alpha, texture(TEXTURE, UV + vec2(0.0, pixel_size.y)).a);    // 下
			min_alpha = min(min_alpha, texture(TEXTURE, UV + vec2(-pixel_size.x, -pixel_size.y)).a); // 左上
			min_alpha = min(min_alpha, texture(TEXTURE, UV + vec2(pixel_size.x, -pixel_size.y)).a);  // 右上
			min_alpha = min(min_alpha, texture(TEXTURE, UV + vec2(-pixel_size.x, pixel_size.y)).a);  // 左下
			min_alpha = min(min_alpha, texture(TEXTURE, UV + vec2(pixel_size.x, pixel_size.y)).a);   // 右下

			// 周围存在透明像素 → 当前像素在边缘内侧 → 绘制轮廓
			if (min_alpha < alpha_threshold) {
				// 根据周围最小 alpha 与阈值的差距计算轮廓强度，使过渡更平滑
				float edge_factor = 1.0 - (min_alpha / alpha_threshold);
				float blend = edge_factor * outline_color.a;
				COLOR = vec4(mix(original_color.rgb, outline_color.rgb, blend), current_alpha);
			} else {
				COLOR = original_color;
			}
		} else {
			COLOR = original_color;
		}
	}
}
