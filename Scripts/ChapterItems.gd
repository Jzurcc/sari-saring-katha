class_name ChapterItems
extends Resource

## A small wrapper that holds the requested items for one specific story chapter.
## Attach these to CustomerData.chapter_request_items (index = chapter number).
## Leave the array empty to fall back to the normal random item shuffle.

@export var upgrade_all: bool = false
@export var items: Array = []
