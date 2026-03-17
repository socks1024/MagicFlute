shader_type canvas_item;

// ==================== 轮廓线着色器 ====================
// 在精灵边缘绘制描边/轮廓线效果，适用于 2D 精灵等 CanvasItem 节点。
// 原理：在顶点着色器中膨胀绘制区域，使轮廓可以渲染在纹理边界之外；
//       在片段着色器中采样周围像素的 alpha 值，如果当前像素透明但
//       周围有不透明像素，则在该位置绘制轮廓颜色。
// 用法：将此 shader 设置为 Sprite2D 等节点的 Material，
//       通过 enabled 参数控制开关，outline_width 控制描边粗细。
// 注意：UV 超出 [0,1] 范围的区域视为完全透明，确保边缘也能正确描边。
// ==================================================

// 是否启用轮廓线效果
uniform bool enabled = false;

// 轮廓线颜色
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// 轮廓线宽度（像素数，值越大描边越粗）
uniform float outline_width : hint_range(0.0, 10.0, 0.5) = 1.0;

// 用于传递膨胀后的 UV 缩放信息
varying vec2 expanded_uv;

void vertex() {
	if (enabled) {
		// 计算膨胀的 UV 边距：outline_width 个像素在 UV 空间中的大小
		vec2 margin = TEXTURE_PIXEL_SIZE * outline_width;

		// 膨胀顶点：根据 UV 判断顶点在哪个角落，向外推
		// UV=0 的方向向负方向推，UV=1 的方向向正方向推
		VERTEX += (UV * 2.0 - 1.0) * outline_width;

		// 重映射 UV：膨胀后的顶点 UV 范围从 [0,1] 映射到 [-margin, 1+margin]
		// 这样原始纹理仍然正确对齐到中心位置
		// UV=0 → -margin, UV=0.5 → 0.5, UV=1 → 1+margin
		expanded_uv = UV * (1.0 + 2.0 * margin) - margin;
	} else {
		expanded_uv = UV;
	}
}

// 安全采样函数：UV 超出 [0,1] 范围时返回完全透明
float safe_alpha(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(tex, uv).a;
}

vec4 safe_texture(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	return texture(tex, uv);
}

void fragment() {
	vec4 original_color = safe_texture(TEXTURE, expanded_uv);

	if (!enabled) {
		COLOR = original_color;
	} else {
		// 当前像素的 alpha 值
		float current_alpha = original_color.a;

		// 采样周围 8 个方向的像素 alpha 值
		vec2 pixel_size = TEXTURE_PIXEL_SIZE * outline_width;

		float surrounding_alpha = 0.0;
		surrounding_alpha += safe_alpha(TEXTURE, expanded_uv + vec2(-pixel_size.x, 0.0));  // 左
		surrounding_alpha += safe_alpha(TEXTURE, expanded_uv + vec2(pixel_size.x, 0.0));   // 右
		surrounding_alpha += safe_alpha(TEXTURE, expanded_uv + vec2(0.0, -pixel_size.y));  // 上
		surrounding_alpha += safe_alpha(TEXTURE, expanded_uv + vec2(0.0, pixel_size.y));   // 下
		surrounding_alpha += safe_alpha(TEXTURE, expanded_uv + vec2(-pixel_size.x, -pixel_size.y)); // 左上
		surrounding_alpha += safe_alpha(TEXTURE, expanded_uv + vec2(pixel_size.x, -pixel_size.y));  // 右上
		surrounding_alpha += safe_alpha(TEXTURE, expanded_uv + vec2(-pixel_size.x, pixel_size.y));  // 左下
		surrounding_alpha += safe_alpha(TEXTURE, expanded_uv + vec2(pixel_size.x, pixel_size.y));   // 右下

		// 如果当前像素透明，但周围有不透明像素 → 绘制轮廓
		if (current_alpha < 0.1 && surrounding_alpha > 0.0) {
			// 轮廓的透明度根据周围像素的密度决定，使边缘更平滑
			float outline_alpha = min(surrounding_alpha / 3.0, 1.0) * outline_color.a;
			COLOR = vec4(outline_color.rgb, outline_alpha);
		} else {
			COLOR = original_color;
		}
	}
}
