import os
import re

items_dir = r'c:\Users\John Reniel\sari-saring-katha\Resources\items'
tier_data = {}

for root, dirs, files in os.walk(items_dir):
    for file in files:
        if file.endswith('.tres'):
            path = os.path.join(root, file)
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    price_match = re.search(r'price = ([\d\.]+)', content)
                    tier_match = re.search(r'tier = (\d+)', content)
                    sold_match = re.search(r'can_be_sold = (false|true)', content)
                    
                    price = float(price_match.group(1)) if price_match else 10.0
                    tier = int(tier_match.group(1)) if tier_match else 1
                    can_be_sold = False if (sold_match and sold_match.group(1) == 'false') else True
                    
                    if can_be_sold:
                        if tier not in tier_data:
                            tier_data[tier] = []
                        tier_data[tier].append(price)
            except:
                pass

# Custom items in tier 10 if not in files
if 10 not in tier_data:
    tier_data[10] = []
# tier_data[10].extend([10.0, 10.0, 0.5]) # Already in files as Aryel, Mentor, Pocha

print(f"{'Tier':<6} | {'Item Count':<10} | {'Sum Base Price':<16} | {'Default Daily Profit (5%)':<28} | {'Max Daily Profit (Tier Cap)':<28}")
print("-" * 105)

for tier in sorted(tier_data.keys()):
    prices = tier_data[tier]
    count = len(prices)
    if count == 0: continue
    sum_base = sum(prices)
    avg_base = sum_base / count
    # 16 sales
    default_profit = 16 * (avg_base * 0.05)
    
    max_margin = 0.15 + (float(max(1, tier)) - 1.0) * (0.20 / 9.0)
    max_profit = 16 * (avg_base * max_margin)
    
    print(f"{tier:<6} | {count:<10} | {sum_base:<16.2f} | {default_profit:<28.2f} | {max_profit:<28.2f}")
