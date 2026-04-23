import os
import re

# Mapping of character directory names to their resource file names
CHARACTER_MAP = {
    "Brahim": "Brahim.tres",
    "Buboy": "Buboy.tres",
    "Danilo": "Danilo.tres",
    "Kuyakap": "KuyaKap.tres",
    "ManangAna": "ManangAna.tres",
    "ReynaMayari": "ReynaMayari.tres",
    "Rodel": "Rodel.tres",
    "Rosalyn": "Rosalyn.tres",
    "Sarimanok": "Sarimanok.tres",
    "TK": "TK.tres"
}

# Generated Arc Names (3 chapters per arc)
ARC_NAMES = {
    "Brahim": ["Arc 1: Low-Resolution Reality", "Arc 2: Debugging the Forest", "Arc 3: System Stable"],
    "Buboy": ["Arc 1: Games and Errands", "Arc 2: Questions on the Porch", "Arc 3: Strawberry Success", "Arc 4: The Masterpiece"],
    "Danilo": ["Arc 1: The Watcher in the Shade", "Arc 2: The Weight of Many Eyes", "Arc 3: The Guardian's Gaze"],
    "Kuyakap": ["Arc 1: The Anchor of Routine", "Arc 2: The Weight of Habits", "Arc 3: Finding Your Float"],
    "ManangAna": ["Arc 1: The Weight of Many Mouths", "Arc 2: Secrets of the Night Flight", "Arc 3: A Balanced Table"],
    "ReynaMayari": ["Arc 1: The Silver Tribute", "Arc 2: Cracks in the Spire", "Arc 3: Patron of the Moon"],
    "Rodel": ["Arc 1: The Abrasive World", "Arc 2: The Drying Search", "Arc 3: The Final Current"],
    "Rosalyn": ["Arc 1: Learning to Hold On", "Arc 2: The Echo of the Rain", "Arc 3: Finding Your Way Out"],
    "Sarimanok": ["Arc 1: The Feathered Critic", "Arc 2: The Silent Auditor", "Arc 3: The Avian Investor"],
    "TK": ["Arc 1: The Viral Scout", "Arc 2: The Viewfinder's Limit", "Arc 3: The Path Forward"]
}

BASE_PATH = r"c:\Users\John Reniel\sari-saring-katha"
RESOURCES_PATH = os.path.join(BASE_PATH, "Resources", "customers")

def update_tres_file(file_path, arc_list):
    if not os.path.exists(file_path):
        print(f"Resource file not found: {file_path}")
        return
    
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    # Convert to Godot array format
    godot_array_str = 'Array[String]([' + ', '.join([f'"{n}"' for n in arc_list]) + '])'
    
    new_lines = []
    found = False
    for line in lines:
        if line.startswith("arc_names ="):
            new_lines.append(f"arc_names = {godot_array_str}\n")
            found = True
        else:
            new_lines.append(line)
            
    if not found:
        # Append at the end of [resource] section
        new_lines.append(f"arc_names = {godot_array_str}\n")
        
    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    print(f"Updated {file_path} with {len(arc_list)} arc names.")

def main():
    for dir_name, tres_name in CHARACTER_MAP.items():
        tres_path = os.path.join(RESOURCES_PATH, tres_name)
        if dir_name in ARC_NAMES:
            update_tres_file(tres_path, ARC_NAMES[dir_name])

if __name__ == "__main__":
    main()
