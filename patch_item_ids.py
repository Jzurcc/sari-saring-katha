import os
import re

# Directory containing the .tres files
ITEMS_BASE_DIR = "Resources/items"

def patch_item_data_ids():
    cwd = os.getcwd()
    items_path = os.path.join(cwd, ITEMS_BASE_DIR)
    
    if not os.path.exists(items_path):
        print(f"Error: Path not found: {items_path}")
        return

    patched_count = 0
    error_count = 0

    # Walk through all subdirectories in Resources/items
    for root, _, files in os.walk(items_path):
        for file in files:
            if file.endswith(".tres"):
                file_path = os.path.join(root, file)
                # The ID is the filename without extension, lowercase
                item_id = os.path.splitext(file)[0].lower()
                
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    # Pattern to find id = "..."
                    # Handles various quotes and potential whitespace
                    id_pattern = r'id\s*=\s*["\'][^"\']*["\']'
                    new_id_line = f'id = "{item_id}"'
                    
                    if re.search(id_pattern, content):
                        # Update existing id field
                        new_content = re.sub(id_pattern, new_id_line, content)
                    else:
                        # Append id field before the last resource block or at a suitable position
                        # Godot .tres usually has [resource] at some point.
                        # We'll try to insert it after the script reference or just after [resource]
                        if '[resource]' in content:
                            new_content = content.replace('[resource]', f'[resource]\nid = "{item_id}"', 1)
                        else:
                            # Fallback: just append (not ideal for .tres but a safety)
                            new_content = content + f'\nid = "{item_id}"'
                    
                    if content != new_content:
                        with open(file_path, 'w', encoding='utf-8') as f:
                            f.write(new_content)
                        print(f"Patched: {file} -> ID: {item_id}")
                        patched_count += 1
                    else:
                        # Even if content is same, it means ID was already correct
                        pass
                        
                except Exception as e:
                    print(f"Error patching {file}: {e}")
                    error_count += 1

    print("\n--- Patching Summary ---")
    print(f"Total files patched/verified: {patched_count}")
    print(f"Errors encountered: {error_count}")
    print("------------------------")

if __name__ == "__main__":
    patch_item_data_ids()
