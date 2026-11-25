import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Resvg } from '@resvg/resvg-js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ICONS_DIR = path.join(__dirname, 'node_modules', 'lucide-static', 'icons');
const OUT_DIR = path.join(__dirname, 'png');

// CLI flags: --size=64 --color=#FFFFFF --stroke=2
const args = process.argv.slice(2);
let size = 64;
let color = '#FFFFFF';
let strokeWidth = null;
const onlyNames = [];

for (const arg of args) {
  if (arg.startsWith('--size=')) size = Math.max(16, parseInt(arg.slice(7), 10) || 64);
  else if (arg.startsWith('--color=')) color = arg.slice(8);
  else if (arg.startsWith('--stroke=')) strokeWidth = arg.slice(9);
  else if (!arg.startsWith('--')) onlyNames.push(arg.replace(/\.svg$/i, ''));
}

if (!fs.existsSync(ICONS_DIR)) {
  console.error('lucide-static icons not found. Run `npm install` first.');
  process.exit(1);
}

fs.mkdirSync(OUT_DIR, { recursive: true });

const files = onlyNames.length > 0
  ? onlyNames.map((n) => `${n}.svg`).filter((f) => fs.existsSync(path.join(ICONS_DIR, f)))
  : fs.readdirSync(ICONS_DIR).filter((f) => f.endsWith('.svg'));

const start = Date.now();
let count = 0;

for (const file of files) {
  let svg = fs.readFileSync(path.join(ICONS_DIR, file), 'utf8');
  svg = svg.replace(/stroke="currentColor"/g, `stroke="${color}"`);
  if (strokeWidth !== null) {
    svg = svg.replace(/stroke-width="[^"]*"/g, `stroke-width="${strokeWidth}"`);
  }
  const resvg = new Resvg(svg, {
    fitTo: { mode: 'width', value: size },
    font: { loadSystemFonts: false },
  });
  const pngBuffer = resvg.render().asPng();
  const outName = file.replace(/\.svg$/i, '.png');
  fs.writeFileSync(path.join(OUT_DIR, outName), pngBuffer);
  count++;
}

const secs = ((Date.now() - start) / 1000).toFixed(2);
console.log(`Converted ${count} Lucide SVG icons -> ${OUT_DIR} (${size}x${size}, ${color}) in ${secs}s.`);
