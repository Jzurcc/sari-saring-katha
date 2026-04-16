import os
import re

customers_dir = r"c:\Users\John Reniel\sari-saring-katha\Resources\customers"

tier_map = {
    "Buboy.tres": 1,
    "Danilo.tres": 1,
    "KuyaKap.tres": 1,
    "ManangAna.tres": 1,
    "Rodel.tres": 1,
    "Rosalyn.tres": 1,
    "Sarimanok.tres": 1,
    "Brahim.tres": 1,
    "TK.tres": 2,
    "ReynaMayari.tres": 3
}

def update_tres(file_path, tier):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # If unlock_tier already exists, update it. Otherwise, add it after dialogic_character.
    if "unlock_tier =" in content:
        new_content = re.sub(r'unlock_tier = \d+', f'unlock_tier = {tier}', content)
    else:
        # Match dialogic_character line and append unlock_tier
        # Godot resources usually look like:
        # dialogic_character = ExtResource("...")
        # story_timelines = [...]
        
        # We find dialogic_character and append unlock_tier after it
        new_content = re.sub(r'(dialogic_character = [^\n]+)', r'\1\nunlock_tier = ' + str(tier), content)
        
    if content != new_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {os.path.basename(file_path)} to Tier {tier}")
    else:
        print(f"No changes needed for {os.path.basename(file_path)}")

for filename, tier in tier_map.items():
    file_path = os.path.join(customers_dir, filename)
    if os.path.exists(file_path):
        update_tres(file_path, tier)
    else:
        print(f"Warning: {filename} not found!")

print("Migration complete.")
