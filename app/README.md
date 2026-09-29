# Digimon Scanner (v2, revisada)

Flutter + Supabase: busca de cartas, scanner OCR, coleções e decks.

## Estrutura
```
app/lib/{data,models,screens,widgets,utils}   código do app
app/test                                      testes (flutter test)
supabase/migrations/0001..0003                esquema do banco
tools/import_cards.py                         importa o catálogo (digimoncard.io)
tools/apply_rules.py + rules.csv              aplica banlist e limites de cópias
```

## Primeira execução
1. Supabase: rode `0001_init.sql`, `0002_collections_rpc.sql` e `0003_deck_updated_at.sql` (SQL Editor).
   Em Authentication, desative "Confirm email" durante o desenvolvimento.
2. Catálogo: `python tools/import_cards.py --dry-run`, depois sem `--dry-run`.
3. Regras: edite `tools/rules.csv` conforme a lista oficial e rode `python tools/apply_rules.py`.
4. App:
   ```bash
   cd app
   flutter create . --project-name digimon_scanner --org com.seudominio
   flutter pub get
   flutter test
   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
   ```
   Use só a chave **anon** no app.

### Câmera
- **Android:** `minSdkVersion` 21 ou mais (`android/app/build.gradle`). O plugin `camera` pede a permissão sozinho.
- **iOS:** adicione `NSCameraUsageDescription` ao `Info.plist` e confira o *deployment target* mínimo no README do pacote `google_mlkit_text_recognition`.

## O que mudou nesta revisão
- **OCR:** o extrator colava letras do nome da carta ao código ("Agumon BT1-010" virava `NBT1-010`). Agora
  mantém os espaços, aceita só prefixos conhecidos (`CardCodeExtractor.prefixes`) e corrige O/I/L apenas dentro do código.
- **Scanner:** câmera só liga na aba ativa e em primeiro plano; volta corretamente depois de segundo plano;
  formato de imagem por plataforma (nv21 / bgra8888); código exige 2 quadros seguidos; leitura a cada 250 ms;
  resolução `high`; erro de permissão com mensagem própria; foto temporária apagada; moldura agora é só guia visual.
- **Decks:** sem códigos fixos na validação (usa `cards.max_copies` e `cards.banned`); tratamento de erro em todas as
  operações; +/− atualiza na hora sem spinner nem perder a rolagem; notas atualizam na tela; curva sem overflow;
  bloqueio de carta banida e de excesso de cópias ao adicionar; a busca de cartas fica aberta para adicionar várias.
- **Importar:** uma consulta em lote (antes eram 2 por linha), aceita `4 BT1-010`, `4x BT1-010`, `BT1-010 x4`,
  reduz ao limite de cópias, ignora banidas e informa cada caso. Importar **define** a quantidade das cartas da lista
  e não apaga as que já estão no deck.
- **Banco:** `decks.updated_at` agora é atualizado por trigger; lista de decks ordenada do mais recente.
- **Testes:** todos em `flutter test` (os antigos usavam `assert` + `dart run`, que não falha sem `--enable-asserts`).

## Limitações conhecidas
- **Banlist:** só `banned` e `max_copies` por carta. As restrições do tipo "escolha uma entre estas cartas" da lista
  oficial não são modeladas. A lista oficial muda; mantenha `rules.csv` atualizado.
- **Formato de exportação** (`4 BT1-010 Nome`): não confirmei compatibilidade com simuladores. O importador do app lê o próprio formato.
- **Scanner:** o OCR lê o quadro inteiro e não distingue artes alternativas (o usuário escolhe na confirmação).
  Ainda depende de teste em aparelho real com cartas reais, luz ruim e reflexo.
- Sem modo offline nem recuperação de senha.
