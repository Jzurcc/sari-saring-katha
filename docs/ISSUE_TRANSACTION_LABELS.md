# Issue: Customer Transaction Label Resolution Failure

## Summary
After the refactor to the resource-based identity system (`CustomerData` and `ItemData`), customer transactions fail to resolve and jump to the correct labels (e.g., `Greeting`, `Talk`, `Satisfy`) in Dialogic timelines. This prevents the progression of story beats and generic purchase flows.

## Environment
- **Branch**: `fix/transaction-label-resolution`
- **Related Files**: 
  - `Scripts/Managers/CustomerSpawner.gd`
  - `Scripts/TransactionContext.gd`
  - `Scripts/Managers/StoryManager.gd`

## Symptom
When a customer arrives or an item is delivered, the expected dialogue phase (e.g., "Satisfy") does not trigger, or the jump to the corresponding label in the `.dtl` file fails silently.

## Suspected Root Cause
In `CustomerSpawner.gd`, the `_is_label_in_timeline` helper uses a simple string matching logic:
```gdscript
var search_pattern = "label " + label_name
if line.strip_edges() == search_pattern:
    return true
```
This fails if:
1.  The timeline file uses tabs instead of spaces.
2.  The label line has trailing comments (e.g., `label Greeting # starts here`).
3.  The `_current_timeline_path` is not correctly resolving for resource-based timelines.

## Steps to Reproduce
1. Start the game.
2. Wait for a customer to arrive.
3. Observe that the greeting occasionally fails or stays stuck.
4. Deliver the correct item and observe if the "Satisfy" dialogue triggers correctly.

## Suggested Fix
Refactor `_is_label_in_timeline` to use a more robust regex or `begins_with` check that accounts for comments and varying whitespace.
Additionally, verify that `Dialogic.Jump.jump_to_label` is only called when the timeline is fully loaded and active.
