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

BASE_PATH = r"c:\Users\John Reniel\sari-saring-katha"
TIMELINES_PATH = os.path.join(BASE_PATH, "Dialogue", "Timelines")
RESOURCES_PATH = os.path.join(BASE_PATH, "Resources", "customers")

def extract_names_from_dtl(file_path):
    names = {}
    if not os.path.exists(file_path):
        return names
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    # Match patterns like: # Chapter 1: "Name" or # Chapter 1 — "Name"
    # Flexible on the separator: :, —, -, .
    regex = r'#\s*Chapter\s*(\d+)\s*[:—\-.]\s*([^(\n\r]+)'
    matches = re.finditer(regex, content, re.IGNORECASE)
    for match in matches:
        idx = int(match.group(1)) - 1 # 0-indexed
        name = match.group(2).strip().strip('"').strip("'")
        # Remove any trailing comments or markers like (DEBUT)
        name = re.split(r'\s*\(', name)[0].strip()
        names[idx] = name
        
    return names

def update_tres_file(file_path, chapter_names_map, max_chapters_from_tres):
    if not os.path.exists(file_path):
        print(f"Resource file not found: {file_path}")
        return
    
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    # Use max_story_chapters from tres to define array size if map is incomplete
    array_size = max_chapters_from_tres
    if chapter_names_map:
        array_size = max(array_size, max(chapter_names_map.keys()) + 1)
        
    chapter_names_array = [""] * array_size
    for idx, name in chapter_names_map.items():
        if idx < array_size:
            chapter_names_array[idx] = name
        
    # Convert to Godot array format
    godot_array_str = 'Array[String]([' + ', '.join([f'"{n}"' for n in chapter_names_array]) + '])'
    
    new_lines = []
    found = False
    for line in lines:
        if line.startswith("chapter_names ="):
            new_lines.append(f"chapter_names = {godot_array_str}\n")
            found = True
        else:
            new_lines.append(line)
            
    if not found:
        # Check if we are in the [resource] section
        in_resource_section = False
        insert_idx = -1
        for i, line in enumerate(new_lines):
            if line.startswith("[resource]"):
                in_resource_section = True
            if in_resource_section and line.strip() == "":
                # End of a block within resource section
                pass
        
        # Simplest is to append at the end of file if not found
        new_lines.append(f"chapter_names = {godot_array_str}\n")
        
    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    print(f"Updated {file_path} with {len([n for n in chapter_names_array if n])} chapter names.")

def get_max_chapters(tres_path):
    if not os.path.exists(tres_path):
        return 0
    with open(tres_path, 'r', encoding='utf-8') as f:
        content = f.read()
    match = re.search(r'max_story_chapters\s*=\s*(\d+)', content)
    if match:
        return int(match.group(1))
    return 0

def main():
    for dir_name, tres_name in CHARACTER_MAP.items():
        dtl_path = os.path.join(TIMELINES_PATH, dir_name, "Story.dtl")
        tres_path = os.path.join(RESOURCES_PATH, tres_name)
        
        print(f"Processing {dir_name}...")
        max_ch = get_max_chapters(tres_path)
        names = extract_names_from_dtl(dtl_path)
        update_tres_file(tres_path, names, max_ch)

if __name__ == "__main__":
    main()
