import sys

def main():
    path = r'c:\Users\John Reniel\sari-saring-katha\Scripts\Managers\CharacterProgressionManager.gd'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace StoryManager. with _get_story_manager().
    # But wait, StoryManager might be used as a standalone word (e.g. is_met(StoryManager)).
    content = content.replace("StoryManager.available_characters", "_get_story_manager().available_characters")
    content = content.replace("StoryManager._save_progression()", "_get_story_manager()._save_progression()")
    content = content.replace("StoryManager.current_tier", "_get_story_manager().current_tier")
    content = content.replace("StoryManager.day", "_get_story_manager().day")
    content = content.replace("StoryManager._game_manager", "_get_story_manager()._game_manager")
    content = content.replace("is_met(StoryManager)", "is_met(_get_story_manager())")
    
    # Add _get_story_manager() func
    helper = """
func _get_story_manager() -> Node:
	return get_node("/root/StoryManager")
"""
    content += helper

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

    print("Patched CharacterProgressionManager.gd")

if __name__ == "__main__":
    main()
