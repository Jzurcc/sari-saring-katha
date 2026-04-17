import os
import re
from collections import defaultdict

items_dir = r'c:\Users\John Reniel\sari-saring-katha\Resources\items'
tier_data = defaultdict(list)

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
                    sold_match = re.search(r'can_be_sold = (false|true)', content)
                    
                    price = float(price_match.group(1)) if price_match else 10.0
                    tier = int(tier_match.group(1)) if tier_match else 1
                    name = name_match.group(1) if name_match else file
                    can_be_sold = False if (sold_match and sold_match.group(1) == 'false') else True
                    
                    if can_be_sold:
                        tier_data[tier].append((name, price))
            except:
                pass

for tier in sorted(tier_data.keys()):
    print(f'### Tier {tier}')
    print('| Item Name | Base Price |')
    print('| :--- | :--- |')
    for name, price in sorted(tier_data[tier]):
        print(f'| {name} | P{price:.2f} |')
    print()
