shader_type canvas_item;

// ==================== 投影着色器 ====================
// 在精灵下方绘制一个偏移的半透明投影副本，模拟投射阴影效果。
// 原理：先在偏移位置采样纹理 alpha 作为投影形状，用投影颜色填充；
//       再在原始位置正常绘制精灵，实现投影叠加在下方的效果。
// 用法：将此 shader 设置为 Sprite2D 等节点的 Material，
//       通过 enabled 参数控制开关，shadow_offset 控制投影偏移方向和距离。
// 注意：需要在 vertex 中膨胀绘制区域，确保偏移后的投影不会被裁切。
// ==================================================

// 是否启用投影效果
uniform bool enabled = false;

// 投影颜色（默认半透明黑色）
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);

// 投影偏移量（像素数，x 正方向为右，y 正方向为下）
uniform vec2 shadow_offset = vec2(3.0, 3.0);

// 用于传递膨胀后的 UV
varying vec2 expanded_uv;

void vertex() {
	if (enabled) {
		// 计算投影偏移在 UV 空间中的大小
		vec2 offset_uv = shadow_offset * TEXTURE_PIXEL_SIZE;

		// 计算各方向需要膨胀的量（只向投影偏移的方向膨胀）
		// 正偏移需要在 UV=1 方向膨胀，负偏移需要在 UV=0 方向膨胀
		vec2 expand_positive = max(shadow_offset, vec2(0.0)); // 正方向膨胀量
		vec2 expand_negative = max(-shadow_offset, vec2(0.0)); // 负方向膨胀量

		// 根据 UV 判断顶点在哪个角落，向对应方向膨胀
		// UV=0 → 向负方向推 expand_negative
		// UV=1 → 向正方向推 expand_positive
		vec2 expand = mix(expand_negative, expand_positive, UV);
		VERTEX += (UV * 2.0 - 1.0) * expand;

		// 计算总膨胀的 UV 边距
		vec2 margin_neg = expand_negative * TEXTURE_PIXEL_SIZE; // UV=0 方向的边距
		vec2 margin_pos = expand_positive * TEXTURE_PIXEL_SIZE; // UV=1 方向的边距

		// 重映射 UV：将 [0,1] 映射到 [-margin_neg, 1+margin_pos]
		expanded_uv = UV * (1.0 + margin_neg + margin_pos) - margin_neg;
	} else {
		expanded_uv = UV;
	}
}

// 安全采样函数：UV 超出 [0,1] 范围时返回完全透明
vec4 safe_texture(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	return texture(tex, uv);
}

void fragment() {
	if (!enabled) {
		COLOR = texture(TEXTURE, UV);
	} else {
		// 采样原始纹理
		vec4 original_color = safe_texture(TEXTURE, expanded_uv);

		// 在偏移位置采样纹理 alpha，作为投影的形状
		vec2 offset_uv = shadow_offset * TEXTURE_PIXEL_SIZE;
		vec4 shadow_sample = safe_texture(TEXTURE, expanded_uv - offset_uv);
		float shadow_alpha = shadow_sample.a * shadow_color.a;

		// 合成：投影在下方，原始精灵在上方
		// 先绘制投影
		vec4 result = vec4(shadow_color.rgb, shadow_alpha);

		// 再将原始精灵叠加在投影上方（标准 alpha 混合）
		result.rgb = mix(result.rgb, original_color.rgb, original_color.a);
		result.a = original_color.a + shadow_alpha * (1.0 - original_color.a);

		COLOR = result;
	}
}
