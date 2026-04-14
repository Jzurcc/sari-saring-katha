import os
import re

items_dir = r'c:\Users\John Reniel\sari-saring-katha\Resources\items'
data = []

for root, dirs, files in os.walk(items_dir):
    for file in files:
        if file.endswith('.tres'):
            path = os.path.join(root, file)
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    price_match = re.search(r'price = ([\d\.]+)', content)
                    tier_match = re.search(r'tier = (\d+)', content)
                    name_match = re.search(r'item_name = "([^"]+)"', content)
                    
                    price = float(price_match.group(1)) if price_match else 10.0
                    tier = int(tier_match.group(1)) if tier_match else 0
                    name = name_match.group(1) if name_match else file
                    
                    data.append({'name': name, 'tier': tier, 'price': price})
            except:
                pass

data.sort(key=lambda x: (x['tier'], x['price']))
for item in data:
    print(f"Tier {item['tier']:2} | {item['price']:6.2f} | {item['name']}")
