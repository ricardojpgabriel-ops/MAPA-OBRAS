# Scanner de Talões — app Flutter (MVP, Fase 1)

App Android (Flutter) que lê um talão dos Jogos Santa Casa com a câmara, extrai os números e a
data, cruza com os resultados oficiais e mostra o prémio. Multiplataforma — preparada para iOS no futuro.

## Arquitetura

```
lib/
  main.dart                 arranque + lista de câmaras
  data/game_config.dart     definição dos jogos e rótulos de prémios
  engine/prize_engine.dart  motor de comparação (portado e validado do protótipo)
  services/
    results_service.dart    lê resultados.json (rede → cache → asset offline)
    ocr_service.dart        Google ML Kit (on-device) + leitura do talão
  ui/                       theme, widgets, home, scan, result
assets/resultados.json      cópia local (1.º arranque / offline)
```

Os resultados vêm do JSON central atualizado pela GitHub Action (`scripts/scrape-santacasa.mjs`).
A app **não faz scraping** — só lê o JSON. Edite `remoteUrl` em `results_service.dart` se mudar o local.

## Como obter o APK

**Sem instalar nada (recomendado):** a GitHub Action *Compilar APK (Android)* gera o APK a cada
push em `app/`. Vá a **Actions → Compilar APK → artefacto `scanner-taloes-apk`** e descarregue.

**Localmente (precisa de Flutter SDK):**
```bash
cd app
flutter create --platforms=android --org com.scannertaloes --project-name scanner_taloes .
# adicionar a permissão de câmara ao AndroidManifest.xml:
#   <uses-permission android:name="android.permission.CAMERA"/>
flutter pub get
flutter run            # ligar o telemóvel por USB (modo programador)
flutter build apk --release
```

## Estado (roadmap)

- [x] **Fase 1** — câmara + OCR (ML Kit) + comparação + resultado. Foco Euromilhões; os 4 jogos já no motor.
- [ ] **Fase 2** — afinar OCR por layout de talão; múltiplas apostas (A–E) por talão.
- [ ] **Fase 3** — leitura em tempo real, robustez com pouca luz/sombras, tratamento de erros.
- [ ] **Fase 4** — Google Play Billing (versão paga) e publicação na Play Store.

## Notas

- minSdk 21 (exigido pelo ML Kit e camera). O build de release é assinado com a chave de debug
  (bom para testes); para a Play Store é preciso criar uma keystore de release.
- Processamento de imagem 100% local (privacidade).
