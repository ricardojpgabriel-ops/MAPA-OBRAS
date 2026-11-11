/**
 * Recolha centralizada de resultados dos Jogos Santa Casa.
 *
 * PORQUÊ centralizar: o site jogossantacasa.pt bloqueia acessos de bots/datacenter
 * (devolve 403/500 a pedidos diretos) e só responde a um browser real com localização
 * em Portugal. Fazer scraping a partir de cada telemóvel seria lento, frágil e bloqueável.
 * Solução: este script corre 1x por dia (GitHub Action / Make / cron), usa o Firecrawl
 * (browser real + proxy) para extrair os resultados e grava-os em euromilhoes/resultados.json.
 * A app só lê esse JSON — rápido, estável e cacheável offline.
 *
 * Requer a variável de ambiente FIRECRAWL_API_KEY.
 * Uso: node scripts/scrape-santacasa.mjs
 */
import { readFileSync, writeFileSync } from 'node:fs';

const KEY = process.env.FIRECRAWL_API_KEY;
if (!KEY) { console.error('Falta FIRECRAWL_API_KEY'); process.exit(1); }

const OUT = new URL('../euromilhoes/resultados.json', import.meta.url);
const MAX_HISTORY = 60; // sorteios guardados por jogo

const TARGETS = {
  euromilhoes: {
    name: 'Euromilhões',
    url: 'https://www.jogossantacasa.pt/web/SCCartazResult/euroMilhoes',
    prompt: 'Extrai do último sorteio do Euromilhões: o número do sorteio (ex "044/2026"), a data do sorteio (DD/MM/AAAA), os 5 números da chave, as 2 estrelas, e a tabela de prémios com cada categoria (ex "5 Números + 2 Estrelas") e o respetivo valor em euros.'
  },
  totoloto: {
    name: 'Totoloto',
    url: 'https://www.jogossantacasa.pt/web/SCCartazResult/totolotoNew',
    prompt: 'Extrai do último sorteio do Totoloto: número do sorteio, data (DD/MM/AAAA), os 5 números da chave, o Número da Sorte, e a tabela de prémios por categoria com o valor em euros.'
  },
  eurodreams: {
    name: 'EuroDreams',
    url: 'https://www.jogossantacasa.pt/web/ResultsBoard/EuroDreams',
    prompt: 'Extrai do último sorteio do EuroDreams: número do sorteio, data (DD/MM/AAAA), os 6 números da chave, o Número de Sonho, e a tabela de prémios por categoria com o valor (alguns são mensalidades).'
  },
  m1lhao: {
    name: 'M1lhão',
    url: 'https://www.jogossantacasa.pt/web/SCCartazResult/m1lhao',
    prompt: 'Extrai do último sorteio do M1lhão: número do sorteio, data (DD/MM/AAAA), o(s) código(s) vencedor(es) (3 letras + 5 dígitos) e o valor do prémio.'
  }
};

const SCHEMA = {
  type: 'object',
  properties: {
    sorteio: { type: 'string' },
    data: { type: 'string', description: 'DD/MM/AAAA' },
    numeros: { type: 'array', items: { type: 'integer' } },
    estrelas: { type: 'array', items: { type: 'integer' } },
    numeroSorte: { type: 'integer' },
    numeroSonho: { type: 'integer' },
    codigos: { type: 'array', items: { type: 'string' } },
    premios: { type: 'array', items: { type: 'object', properties: { categoria: { type: 'string' }, valor: { type: 'string' } } } }
  }
};

async function scrape(t) {
  const res = await fetch('https://api.firecrawl.dev/v2/scrape', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      url: t.url,
      formats: [{ type: 'json', prompt: t.prompt, schema: SCHEMA }],
      location: { country: 'PT', languages: ['pt-PT'] },
      onlyMainContent: true,
      waitFor: 5000
    })
  });
  const j = await res.json();
  if (!j.success) throw new Error('Firecrawl: ' + JSON.stringify(j).slice(0, 200));
  return j.data.json;
}

function isoDate(d) { const m = String(d).match(/(\d{2})\/(\d{2})\/(\d{4})/); return m ? `${m[3]}-${m[2]}-${m[1]}` : null; }

// Converte a categoria textual da Santa Casa na chave usada pela app
function tierKey(game, cat) {
  const c = cat.toLowerCase();
  const nums = (c.match(/(\d+)\s*n[úu]mero/) || [])[1];
  if (game === 'euromilhoes') {
    const est = (c.match(/(\d+)\s*estrela/) || [])[1] || '0';
    return nums ? `${nums}+${est}` : null;
  }
  if (game === 'totoloto') {
    if (/n[úu]mero da sorte/.test(c) && nums) return `${nums}+S`;
    if (/n[úu]mero da sorte/.test(c)) return 'S';
    return nums || null;
  }
  if (game === 'eurodreams') {
    if (/sonho/.test(c) && nums) return `${nums}+D`;
    return nums || null;
  }
  return null;
}

function toDraw(game, j) {
  const draw = { id: j.sorteio, date: isoDate(j.data) };
  if (game === 'm1lhao') {
    draw.codes = j.codigos || [];
    draw.prize = (j.premios && j.premios[0] && j.premios[0].valor) || '€ 1.000.000,00';
    return draw;
  }
  draw.numbers = j.numeros || [];
  if (game === 'euromilhoes') draw.stars = j.estrelas || [];
  if (game === 'totoloto') draw.sorte = j.numeroSorte;
  if (game === 'eurodreams') draw.sonho = j.numeroSonho;
  draw.tiers = {};
  for (const p of (j.premios || [])) {
    const k = tierKey(game, p.categoria || '');
    if (k) draw.tiers[k] = p.valor || '—';
  }
  return draw;
}

async function main() {
  let data;
  try { data = JSON.parse(readFileSync(OUT, 'utf8')); }
  catch { data = { source: 'https://www.jogossantacasa.pt', games: {} }; }

  for (const [game, t] of Object.entries(TARGETS)) {
    try {
      const j = await scrape(t);
      const draw = toDraw(game, j);
      if (!draw.id || !draw.date) { console.warn(`${game}: dados incompletos, ignorado`); continue; }
      const g = data.games[game] || (data.games[game] = { name: t.name, url: t.url, draws: [] });
      g.draws = g.draws.filter((d) => d.id !== draw.id);   // substitui se já existir
      g.draws.unshift(draw);                                // mais recente primeiro
      g.draws = g.draws.slice(0, MAX_HISTORY);
      console.log(`${game}: ${draw.id} (${draw.date}) OK`);
    } catch (e) {
      console.error(`${game}: ERRO -`, e.message);
    }
  }

  data.updated = new Date().toISOString();
  writeFileSync(OUT, JSON.stringify(data, null, 2) + '\n');
  console.log('resultados.json atualizado.');
}

main();
