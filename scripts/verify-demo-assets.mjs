import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

const root = new URL('../', import.meta.url);
const manifest = JSON.parse(readFileSync(new URL('game/assets/manifest.json', root), 'utf8'));
if (!Array.isArray(manifest) || !manifest.length) throw new Error('Empty asset manifest');
for (const entry of manifest) {
  if (!entry.path.startsWith('game/assets/') || entry.path.includes('..')) {
    throw new Error(`Invalid asset path: ${entry.path}`);
  }
  const bytes = readFileSync(new URL(entry.path, root));
  const sha256 = createHash('sha256').update(bytes).digest('hex');
  if (bytes.length !== entry.bytes || sha256 !== entry.sha256) {
    throw new Error(`Asset integrity check failed: ${entry.path}`);
  }
}
for (const name of ['20204.png', '98398.png', '3eebe.png']) {
  if (!manifest.some(entry => entry.path === `game/assets/figma/${name}`)) {
    throw new Error(`Original Figma image missing from manifest: ${name}`);
  }
}
console.log(`Verified ${manifest.length} bundled assets (size and SHA-256).`);
