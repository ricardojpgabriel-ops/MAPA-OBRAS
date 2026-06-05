// Gera os icones PNG da PWA sem dependencias externas (usa apenas o zlib do Node).
// Desenha um fundo verde (estilo Santa Casa) com 5 bolas brancas + 2 estrelas douradas.
import zlib from 'node:zlib';
import { writeFileSync } from 'node:fs';

function crc32(buf) {
  let c = ~0;
  for (let i = 0; i < buf.length; i++) {
    c ^= buf[i];
    for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xEDB88320 & -(c & 1));
  }
  return (~c) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0);
  const t = Buffer.from(type, 'ascii');
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(Buffer.concat([t, data])), 0);
  return Buffer.concat([len, t, data, crc]);
}
function encodePNG(w, h, rgba) {
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 6; // 8-bit, RGBA
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0; // filter 0
    rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  }
  const idat = zlib.deflateSync(raw, { level: 9 });
  return Buffer.concat([sig, chunk('IHDR', ihdr), chunk('IDAT', idat), chunk('IEND', Buffer.alloc(0))]);
}

function makeIcon(S) {
  const buf = Buffer.alloc(S * S * 4);
  const set = (x, y, r, g, b, a = 255) => {
    if (x < 0 || y < 0 || x >= S || y >= S) return;
    const i = (y * S + x) * 4;
    const ca = a / 255, ia = 1 - ca;
    buf[i]   = Math.round(r * ca + buf[i] * ia);
    buf[i+1] = Math.round(g * ca + buf[i+1] * ia);
    buf[i+2] = Math.round(b * ca + buf[i+2] * ia);
    buf[i+3] = Math.max(buf[i+3], a);
  };
  const disc = (cx, cy, rad, col) => {
    for (let y = Math.floor(cy - rad - 1); y <= cy + rad + 1; y++)
      for (let x = Math.floor(cx - rad - 1); x <= cx + rad + 1; x++) {
        const d = Math.hypot(x + 0.5 - cx, y + 0.5 - cy);
        if (d <= rad - 0.5) set(x, y, col[0], col[1], col[2]);
        else if (d <= rad + 0.5) set(x, y, col[0], col[1], col[2], Math.round((rad + 0.5 - d) * 255));
      }
  };
  // fundo: cantos arredondados, verde Santa Casa
  const R = S * 0.18, green = [0, 132, 61];
  for (let y = 0; y < S; y++)
    for (let x = 0; x < S; x++) {
      const dx = Math.min(x, S - 1 - x), dy = Math.min(y, S - 1 - y);
      let inside = true;
      if (dx < R && dy < R) inside = Math.hypot(R - dx, R - dy) <= R;
      if (inside) { const i = (y * S + x) * 4; buf[i] = green[0]; buf[i+1] = green[1]; buf[i+2] = green[2]; buf[i+3] = 255; }
    }
  // 5 bolas brancas
  const r = S * 0.078, cy = S * 0.42;
  for (let n = 0; n < 5; n++) disc(S * (0.18 + n * 0.13), cy, r, [255, 255, 255]);
  // 2 estrelas douradas (representadas por bolas) em baixo
  const cy2 = S * 0.66, gold = [251, 186, 0];
  disc(S * 0.40, cy2, r * 0.92, gold);
  disc(S * 0.56, cy2, r * 0.92, gold);
  return encodePNG(S, S, buf);
}

for (const s of [192, 512]) {
  writeFileSync(new URL(`../euromilhoes/icon-${s}.png`, import.meta.url), makeIcon(s));
  console.log(`icon-${s}.png gerado`);
}
writeFileSync(new URL('../euromilhoes/icon-180.png', import.meta.url), makeIcon(180));
console.log('icon-180.png gerado');
