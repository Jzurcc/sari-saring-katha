import os

def update_scene():
    with open('Scenes/MainMenu.tscn', 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Add ext_resource for the shader
    shader_ext = '[ext_resource type="Shader" path="res://Shaders/UIBlurGlow.gdshader" id="shader_blur"]\n'
    last_ext_idx = content.rfind('[ext_resource')
    if last_ext_idx != -1:
        end_of_ext = content.find('\\n', last_ext_idx) + 1
        content = content[:end_of_ext] + shader_ext + content[end_of_ext:]

    # 2. Add sub_resources
    sub_res = """
[sub_resource type="ShaderMaterial" id="ShaderMaterial_blur"]
shader = ExtResource("shader_blur")
shader_parameter/blur_radius = 6.0

[sub_resource type="CanvasItemMaterial" id="CanvasItemMaterial_add"]
blend_mode = 1
next_pass = SubResource("ShaderMaterial_blur")

[sub_resource type="ViewportTexture" id="ViewportTexture_glow"]
viewport_path = NodePath("GlowViewportContainer/GlowViewport")

"""
    first_node_idx = content.find('\\n[node')
    if first_node_idx != -1:
        content = content[:first_node_idx] + sub_res + content[first_node_idx:]

    # 3. Replace Buttons container definition and insert GlowViewport logic right before it
    btn_str = '[node name="Buttons" type="VBoxContainer" parent="."'
    btn_replacement = """[node name="GlowViewportContainer" type="SubViewportContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
stretch = true

[node name="GlowViewport" type="SubViewport" parent="GlowViewportContainer"]
transparent_bg = true
handle_input_locally = false
size = Vector2i(1152, 648)
render_target_update_mode = 4

[node name="Buttons" type="VBoxContainer" parent="GlowViewportContainer/GlowViewport\""""
    
    content = content.replace(btn_str, btn_replacement)

    # 4. Insert TextureRect just before OptionsOverlay
    texture_rect = """[node name="GlowOverlay" type="TextureRect" parent="."]
material = SubResource("CanvasItemMaterial_add")
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
texture = SubResource("ViewportTexture_glow")
expand_mode = 1

"""
    opt_idx = content.find('[node name="OptionsOverlay"')
    if opt_idx != -1:
        content = content[:opt_idx] + texture_rect + content[opt_idx:]

    with open('Scenes/MainMenu.tscn', 'w', encoding='utf-8') as f:
        f.write(content)

update_scene()
