import os
import re
from collections import defaultdict

items_dir = r'c:\Users\John Reniel\sari-saring-katha\Resources\items'
cat_data = defaultdict(list)

for root, dirs, files in os.walk(items_dir):
    for file in files:
        if file.endswith('.tres'):
            path = os.path.join(root, file)
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    price_match = re.search(r'price = ([\d\.]+)', content)
                    tier_match = re.search(r'tier = (\d+)', content)
                    name_match = re.search(r'item_name = \"([^\"]+)\"', content)
                    cat_match = re.search(r'category = \"([^\"]+)\"', content)
                    sold_match = re.search(r'can_be_sold = (false|true)', content)
                    
                    price = float(price_match.group(1)) if price_match else 10.0
                    tier = int(tier_match.group(1)) if tier_match else 1
                    name = name_match.group(1) if name_match else file
                    category = cat_match.group(1) if cat_match else 'other'
                    can_be_sold = False if (sold_match and sold_match.group(1) == 'false') else True
                    
                    if can_be_sold:
                        cat_data[category].append((tier, price, name))
            except:
                pass

for cat in sorted(cat_data.keys()):
    print(f'### Category: {cat.capitalize()}')
    print('| Tier | Base Price | Item Name |')
    print('| :--- | :--- | :--- |')
    # Sort by tier then price
    for tier, price, name in sorted(cat_data[cat], key=lambda x: (x[0], x[1])):
        print(f'| {tier} | P{price:.2f} | {name} |')
    print()
