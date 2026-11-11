import os

def replace_in_file(path, old, new):
    if not os.path.exists(path): return
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    content = content.replace(old, new)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def main():
    root = r'c:\Users\John Reniel\sari-saring-katha\Scripts'
    
    # 1. DialogicBridge.gd
    db_path = os.path.join(root, 'Helpers', 'DialogicBridge.gd')
    if os.path.exists(db_path):
        with open(db_path, 'r', encoding='utf-8') as f:
            db_content = f.read()
        if 'class_name DialogicBridge' not in db_content:
            db_content = 'class_name DialogicBridge\n' + db_content
            with open(db_path, 'w', encoding='utf-8') as f:
                f.write(db_content)
                
    # 2. PlayerInteraction.gd
    pi_path = os.path.join(root, 'Components', 'PlayerInteraction.gd')
    replace_in_file(pi_path, 'var is_tutorial_task = gm and gm.is_tutorial_task_active', 'var is_tutorial_task = gm and gm.tutorial.is_tutorial_task_active')
    replace_in_file(pi_path, 'var hit_gaze = {}', 'var _hit_gaze = {}')

    # 3. CustomerSpawner.gd
    cs_path = os.path.join(root, 'Managers', 'CustomerSpawner.gd')
    replace_in_file(cs_path, 'func _spawn_next_customer(delay: float', 'func _spawn_next_customer(_delay: float')
    
    # 4. StoryManager.gd
    sm_path = os.path.join(root, 'Managers', 'StoryManager.gd')
    replace_in_file(sm_path, 'var _debug_sarimanok_cycle: Array', '#var _debug_sarimanok_cycle: Array')
    replace_in_file(sm_path, 'func _pick_character_weighted(candidates: Array', 'func _pick_character_weighted(_candidates: Array')

    # 5. InventoryManager.gd
    im_path = os.path.join(root, 'InventoryManager.gd')
    replace_in_file(im_path, 'var pricing_flags =', 'var _pricing_flags =')

    # 6. IntroManager.gd (might be in Managers or UI or root)
    for sub in ['', 'Managers', 'UI']:
        intro_path = os.path.join(root, sub, 'IntroManager.gd')
        replace_in_file(intro_path, 'var total_duration =', 'var _total_duration =')
        
    # 7. PauseMenu.gd
    pm_path = os.path.join(root, 'UI', 'PauseMenu.gd')
    replace_in_file(pm_path, 'var _original_music_db', '#var _original_music_db')

    # 8. NokiaUI.gd
    nk_path = os.path.join(root, 'UI', 'NokiaUI.gd')
    replace_in_file(nk_path, 'var store_menu =', 'var _store_menu_local =')

    # 9. RestockMenu.gd
    rm_path = os.path.join(root, 'UI', 'RestockMenu.gd')
    replace_in_file(rm_path, 'func _on_minus_pressed(row: Node', 'func _on_minus_pressed(_row: Node')
    
    # 10. TierAdvanceOverlay.gd
    to_path = os.path.join(root, 'UI', 'TierAdvanceOverlay.gd')
    replace_in_file(to_path, 'func _input(event: InputEvent', 'func _input(_event: InputEvent')

    # 11. DayTimeUI.gd
    dt_path = os.path.join(root, 'UI', 'DayTimeUI.gd')
    replace_in_file(dt_path, 'var gm :=', 'var _gm :=')
    
    # Project godot
    proj = r'c:\Users\John Reniel\sari-saring-katha\project.godot'
    replace_in_file(proj, 'DialogicBridge="*res://Scripts/Helpers/DialogicBridge.gd"\n', '')

    print("Patched warnings and errors")

if __name__ == "__main__":
    main()
