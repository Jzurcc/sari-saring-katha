import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PNG_DIR = path.join(__dirname, 'png');
const TARGET_DIR = path.resolve(__dirname, '..', '..', 'Assets', 'ui', 'icons');

const names = process.argv.slice(2).map((n) => n.replace(/\.(png|svg)$/i, ''));
if (names.length === 0) {
  console.log('Usage: npm run pick -- <icon-name-1> <icon-name-2> ...');
  console.log('Example: npm run pick -- brush eraser paint-bucket pipette type move eye eye-off undo-2 redo-2 zoom-in zoom-out upload trash-2');
  process.exit(0);
}

fs.mkdirSync(TARGET_DIR, { recursive: true });

let copied = 0;
for (const name of names) {
  const src = path.join(PNG_DIR, `${name}.png`);
  if (!fs.existsSync(src)) {
    console.warn(`Missing icon: ${name}.png (run \`npm run build\` first or check Lucide icon name)`);
    continue;
  }
  const dst = path.join(TARGET_DIR, `${name}.png`);
  fs.copyFileSync(src, dst);
  console.log(`Copied -> Assets/ui/icons/${name}.png`);
  copied++;
}
console.log(`Done: ${copied}/${names.length} icon(s) copied to Assets/ui/icons/.`);
