"""
patch_item_ids.py
-----------------
Scans every .tres file under Resources/items/ and injects an `id` field
into the [resource] section if one is not already present (or is blank).

The id value is the filename stem, lowercased.
  Gin.tres       → id = "gin"
  KneesToes.tres → id = "kneestoes"
  Marboro.tres   → id = "marboro"

Safe to re-run: files that already have a non-empty id are skipped.
"""

import os
import re
from pathlib import Path

ITEMS_ROOT = Path(__file__).parent / "Resources" / "items"


def patch_file(path: Path) -> bool:
    """
    Returns True if the file was modified.
    """
    text = path.read_text(encoding="utf-8")
    stem_id = path.stem.lower()

    # ── Check whether id is already set and non-empty ──────────────────────
    # We only look inside the [resource] section to avoid false positives
    # from ext_resource id="..." attributes which use a different syntax.
    resource_section = re.search(r'\[resource\](.*)', text, re.DOTALL)
    if not resource_section:
        print(f"  SKIP  {path.name} — no [resource] section found")
        return False

    section_body = resource_section.group(1)

    # Match a line like: id = "something"
    existing = re.search(r'^id\s*=\s*"([^"]*)"', section_body, re.MULTILINE)
    if existing and existing.group(1) != "":
        print(f"  SKIP  {path.name} — id already set to \"{existing.group(1)}\"")
        return False

    # ── Insert or replace the id line ──────────────────────────────────────
    new_line = f'id = "{stem_id}"'

    if existing:
        # Replace the blank id = "" with the real value
        new_section_body = re.sub(
            r'^id\s*=\s*""',
            new_line,
            section_body,
            count=1,
            flags=re.MULTILINE,
        )
        new_text = text[: resource_section.start(1)] + new_section_body
    else:
        # Insert id right after the [resource] header line
        new_text = re.sub(
            r'(\[resource\]\n)',
            rf'\1{new_line}\n',
            text,
            count=1,
        )

    path.write_text(new_text, encoding="utf-8")
    print(f"  PATCH {path.name} -> id = \"{stem_id}\"")
    return True


def main():
    tres_files = sorted(ITEMS_ROOT.rglob("*.tres"))
    if not tres_files:
        print(f"No .tres files found under {ITEMS_ROOT}")
        return

    patched = 0
    for f in tres_files:
        if patch_file(f):
            patched += 1

    print(f"\nDone. {patched}/{len(tres_files)} file(s) patched.")


if __name__ == "__main__":
    main()
