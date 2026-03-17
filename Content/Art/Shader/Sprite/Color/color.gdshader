shader_type canvas_item;

// ==================== 基础颜色着色器 ====================
// 将精灵所有不透明像素替换为指定的纯色。
// 适用于：角色死亡剪影、远景层叠、前景遮挡、隐藏在障碍物后的
//         角色轮廓显示等场景。
// 用法：将此 shader 设置为 Sprite2D 等节点的 Material，
//       通过 color_amount 参数（0.0 ~ 1.0）控制着色强度。
//       0.0 = 原始颜色，1.0 = 完全着色。
// =================================================

// 着色颜色（默认黑色）
uniform vec4 base_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// 着色强度：0.0 = 原始颜色，1.0 = 完全着色
uniform float color_amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// 采样原始纹理颜色
	vec4 original_color = texture(TEXTURE, UV);

	// 将原始 RGB 与目标颜色按强度混合，保留原始 Alpha
	vec3 final_rgb = mix(original_color.rgb, base_color.rgb, color_amount);

	// Alpha 也可以受目标颜色的 alpha 影响（当目标颜色半透明时）
	float final_alpha = original_color.a * mix(1.0, base_color.a, color_amount);

	COLOR = vec4(final_rgb, final_alpha);
}
