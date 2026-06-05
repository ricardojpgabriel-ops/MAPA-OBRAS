# Scanner de Talões — Jogos Santa Casa

App que lê um talão (Euromilhões, Totoloto, EuroDreams, M1lhão) com a câmara, identifica o
jogo e a data do sorteio, cruza com os resultados oficiais e diz logo se há prémio e qual o valor.

Esta pasta contém um **protótipo funcional (PWA)** que já corre no telemóvel e prova todo o
pipeline (câmara → OCR → comparação → prémio). Serve de MVP da Fase 1 e de especificação
para a versão nativa/Flutter.

## O que já está feito

| Peça | Implementação | Ficheiro |
|------|---------------|----------|
| Interface (câmara + manual + resultado) | HTML/CSS/JS, instalável (PWA) | `index.html` |
| OCR | Tesseract.js (`por`), 100% no telemóvel | em `index.html` |
| Motor de comparação | 4 jogos, com tabela de prémios por categoria | em `index.html` |
| Resultados oficiais | JSON central (dados reais recolhidos do site) | `resultados.json` |
| Recolha automática | scraper via Firecrawl (browser real) | `../scripts/scrape-santacasa.mjs` |
| Atualização diária | GitHub Action agendada | `../.github/workflows/resultados.yml` |

## Descoberta importante (define a arquitetura)

O site **jogossantacasa.pt bloqueia bots**: pedidos diretos de servidores/datacenter
devolvem `403/500`. Só responde a um **browser real com localização em Portugal**.

➡️ Por isso **a app NÃO faz scraping a partir de cada telemóvel**. Em vez disso, um processo
central (Action/Make/cron) recolhe os resultados 1x por dia e grava-os em `resultados.json`.
A app só lê esse JSON — rápido, estável, cacheável offline e à prova de mudanças de layout do site.

```
[Action diária + Firecrawl]  →  resultados.json  →  [App no telemóvel]
   (browser real, IP PT)         (no GitHub Pages)      (lê + compara, offline)
```

## Testar agora (no telemóvel Android)

A app precisa de ser servida por HTTPS (a câmara não funciona em `file://`).

**Opção A — GitHub Pages (mais simples):**
1. Settings → Pages → ativar Pages a partir deste branch.
2. Abrir no Chrome do Android: `https://<utilizador>.github.io/<repo>/euromilhoes/`
3. Menu do Chrome → **“Instalar app” / “Adicionar ao ecrã principal”**.

**Opção B — local:**
```bash
cd euromilhoes && python3 -m http.server 8080
# abrir http://localhost:8080  (no PC) ou via IP na mesma rede Wi-Fi
```

## Recolha automática de resultados

1. Criar conta em [firecrawl.dev](https://firecrawl.dev) e obter a API key.
2. No repositório: Settings → Secrets and variables → Actions → novo secret `FIRECRAWL_API_KEY`.
3. A Action corre todos os dias às ~23:30 (PT) e faz commit do `resultados.json` atualizado.
   Pode também correr-se à mão em Actions → *Atualizar resultados* → *Run workflow*.

Localmente:
```bash
FIRECRAWL_API_KEY=xxx node scripts/scrape-santacasa.mjs
```

> Alternativa sem Firecrawl: replicar a mesma lógica num cenário **Make.com** (browser/HTTP com
> proxy PT) que escreve o `resultados.json` por commit na API do GitHub, ou numa base de dados
> (Supabase/Firebase) que a app consulta por REST.

## Caminho para a Play Store (app paga)

O PWA instala-se já, mas para **vender na Play Store com Google Play Billing** o caminho é uma
app nativa/Flutter. Recomendação de stack na conversa. Resumo:

- **OCR de produção:** Google ML Kit Text Recognition (on-device, offline, mais rápido e preciso
  que o Tesseract; mantém o processamento da imagem no telemóvel → privacidade).
- **Dados:** o mesmo `resultados.json`/endpoint central já definido aqui.
- **Billing:** Google Play Billing (validação de compra premium).

A lógica de comparação e a tabela de prémios desta pasta servem diretamente de referência para o
port. Estrutura de dados em `resultados.json`.

## Aviso

App não oficial. Confirme sempre o resultado e o prémio em jogossantacasa.pt antes de reclamar.
Jogo reservado a maiores de 18 anos.
