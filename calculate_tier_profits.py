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
                    sold_match = re.search(r'can_be_sold = (false|true)', content)
                    
                    price = float(price_match.group(1)) if price_match else 10.0
                    tier = int(tier_match.group(1)) if tier_match else 1
                    can_be_sold = False if (sold_match and sold_match.group(1) == 'false') else True
                    
                    if can_be_sold:
                        tier_data[tier].append(price)
            except:
                pass

# Projections based on 15 customers, averaging 2 items each = 30 sales per day
SALES_PER_DAY = 30

print("--- TIER BY TIER MAX PROFIT (If selling ONLY that tier) ---")
print(f"{'Tier':<6} | {'Item Count':<10} | {'Sum Base':<10} | {'Max Daily Profit (30% or +P5)':<28}")
print("-" * 65)

individual_tier_results = {}

for tier in sorted(tier_data.keys()):
    prices = tier_data[tier]
    count = len(prices)
    if count == 0: continue
    
    tier_max_profit = 0
    for price in prices:
        # Profit per unit: max(30%, 5.0)
        max_unit_profit = max(price * 0.30, 5.0)
        # Average sale contribution
        tier_max_profit += (SALES_PER_DAY / count) * max_unit_profit
    
    individual_tier_results[tier] = tier_max_profit
    print(f"{tier:<6} | {count:<10} | {sum(prices):<10.2f} | {tier_max_profit:<28.2f}")

print("\n--- CUMULATIVE AVERAGE MAX PROFIT (All tiers unlocked up to X) ---")
print(f"{'Tier':<6} | {'Total Items':<12} | {'Avg Profit/Item':<18} | {'Total Daily Max':<18}")
print("-" * 65)

all_unlocked_prices = []
for tier in sorted(tier_data.keys()):
    all_unlocked_prices.extend(tier_data[tier])
    
    count = len(all_unlocked_prices)
    total_unit_profit_sum = sum(max(p * 0.30, 5.0) for p in all_unlocked_prices)
    avg_profit_per_item = total_unit_profit_sum / count
    total_daily_max = SALES_PER_DAY * avg_profit_per_item
    
    print(f"{tier:<6} | {count:<12} | {avg_profit_per_item:<18.2f} | {total_daily_max:<18.2f}")
