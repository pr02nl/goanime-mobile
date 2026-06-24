# PauloFlix — Enriquecimento via NFO/JPG/poster do Servidor

> **For Hermes:** Use subagent-driven-development para implementar este plano task-by-task. Cada Fase é uma sequência TDD (test red → impl → green) com `flutter analyze` + `flutter test` no fim.

**Goal:** Substituir (parcialmente) o enriquecimento Jikan/TMDB do `PauloFlixService` e `PauloFlixMoviesService` por leitura direta de `tvshow.nfo` / `movie.nfo` + `poster.jpg` / `fanart.jpg` / `S01E001-thumb.jpg` do servidor PauloFlix. Quando o NFO está disponível, ele vira a fonte primária; Jikan/TMDB só é chamado como fallback.

**Architecture:**
- Criar `KodiNfoParser` puro (sem Flutter) que faz parse XML e retorna DTOs imutáveis.
- Criar `PauloFlixNfoEnricher` que orquestra o scraping de arquivos NFO/JPG via `AuthenticatedHttpClient` (injetado, reaproveitando o JWT manager existente).
- Integrar o enricher no `PauloFlixService.syncContent` e `PauloFlixMoviesService.syncContent` antes/depois do enriquecimento Jikan/TMDB.
- Adicionar `episodeImageUrl` ao schema `paulo_flix_episodes` (migration v5→v6) + propagate pelo `PauloFlixEpisodeProgressRepository`.

**Tech Stack:** `xml` package (não `html`), `AuthenticatedHttpClient` (existente), Drift migration v6, sem novos heavy deps.

---

## Decisões validadas com o usuário

✅ **Escopo:** PauloFlix animes **E** PauloFlix Movies — ambos no mesmo PR.
✅ **HTTP:** `AuthenticatedHttpClient` (wrapper com JWT Ed25519 já existe em `lib/data/services/auth/`).
✅ **Cobertura NFO:** **Mínimo viável** — `title`, `plot`, `genre`, `year`, `season`/`episode number`, `thumb`, `poster`, `fanart`. Outros campos (studio, actor, mpaa, premiered) ficam fora desta primeira versão.
✅ **Visual:** thumb no card de episódio + `fanart.jpg` no hero. Season-level `season{N}.jpg` (Kodi convention) **não** é lido nesta versão.
✅ **Sync semantics:** NFO é **primário**; Jikan/TMDB é **fallback** (só chamado se NFO ausente ou campo vazio).
✅ **Tracking:** **Sem coluna nova** — só `debugPrint`. Re-tentativa automática via TTL 7 dias existente.

### Defaults assumidos (não perguntados — corrigir no code review)

- `xml` package adicionado ao `pubspec.yaml` (sem `html` para parse NFO — `html` é para HTML, `xml` é para XML).
- Thumbnail de episódio: detectado pelo regex `S\d+E(\d+)-thumb\.(jpg|jpeg|png|webp)$` no listing da season.
- Formato do episode number extraído do NFO: `<episodedetails><episode>N</episode>` (Kodi standard).
- Imagens NFO: se `<thumb>` existe e é URL absoluta, usa direto; se é caminho relativo, monta `serverUrl + thumb`.
- Quando NFO tem `<thumb>` mas a URL HTTP 404, **não** chama Jikan — deixa `imageUrl` null e loga. (Jikan só é chamado no fluxo legado de enrichment de `PauloFlixContent`).
- Race conditions: se 2 syncs rodam em paralelo (ex: app reabre + sync automático), o `insertOrReplace` do Drift resolve — última escrita ganha, mas como o conteúdo é o mesmo (mesmo NFO), não há perda de dados.

---

## Estrutura de arquivos

### Novos arquivos
- `lib/data/services/kodi/kodi_nfo_parser.dart` — parser XML puro (sem Flutter)
- `lib/data/services/kodi/kodi_nfo_models.dart` — DTOs imutáveis (KodiShowNfo, KodiMovieNfo, KodiSeasonNfo, KodiEpisodeNfo)
- `lib/data/services/kodi/pauloflix_nfo_enricher.dart` — orquestrador HTTP + parser
- `lib/data/services/auth/authenticated_http_client.dart` — já existe, mas adicionar `dispose` para fechar o inner client (gotcha 2: BaseClient sem dispose vaza socket)
- `test/data/services/kodi/kodi_nfo_parser_test.dart` — testes unitários do parser
- `test/data/services/kodi/pauloflix_nfo_enricher_test.dart` — testes do enricher (com `MockClient` do `http/testing.dart`)

### Arquivos modificados
- `pubspec.yaml` — adicionar `xml: ^6.5.0`
- `lib/data/services/pauloflix_service.dart` — injetar `PauloFlixNfoEnricher` no `syncContent`, chamar antes do Jikan
- `lib/data/services/pauloflix_movies_service.dart` — mesmo, para movies
- `lib/core/database/app_database.dart` — `schemaVersion` 5 → 6
- `lib/core/database/tables/paulo_flix_episodes.dart` — adicionar coluna `thumbnailUrl: text().nullable()`
- `lib/data/repositories/paulo_flix_episode_progress_repository_impl.dart` — incluir `thumbnailUrl` no `_toEpisodeDomain` e no `upsertEpisode`
- `lib/domain/models/paulo_flix_episode_record.dart` — adicionar `thumbnailUrl`
- `lib/domain/repositories/paulo_flix_episode_progress_repository.dart` — adicionar `String? thumbnailUrl` no contrato `upsertEpisode`
- `lib/data/services/paulo_flix_episode_sync_service.dart` — extrair `thumbnailUrl` do listing da season e passar para `upsertEpisode`
- `lib/ui/pauloflix/view_models/paulo_flix_episode_progress_viewmodel.dart` — expor `thumbnailUrl` no `scrapingEpisodesForSelected`
- `lib/ui/pauloflix/widgets/pauloflix_episode_list_screen.dart` — usar `thumb` no card (com fallback pro gradient atual)
- `lib/ui/player/widgets/episode_grid_card.dart` — suportar `Episode.thumbnailUrl` (opcional)
- `lib/domain/models/episode.dart` — adicionar `String? thumbnailUrl` (model compartilhado)
- `test/data/repositories/paulo_flix_episode_progress_repository_impl_test.dart` — atualizar fixture (se existir) para incluir o novo campo

### Novos testes
- `test/data/services/kodi/kodi_nfo_parser_test.dart` — 12+ casos (NFO válido, inválido, vazio, com campos faltando)
- `test/data/services/kodi/pauloflix_nfo_enricher_test.dart` — 8+ casos (HTTP 200, 404, 500, timeout, parser error, batch parallel)

---

## Algoritmos críticos

### 1. Parse de `tvshow.nfo` (Kodi)

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<tvshow>
  <title>Mushoku Tensei</title>
  <plot>Um homem... reencarna em outro mundo.</plot>
  <genre>Action</genre>
  <genre>Adventure</genre>
  <genre>Fantasy</genre>
  <premiered>2021-01-11</premiered>
  <year>2021</year>
  <rating>8.4</rating>
  <thumb aspect="poster">poster.jpg</thumb>
  <thumb aspect="banner">banner.jpg</thumb>
  <thumb aspect="fanart">fanart.jpg</thumb>
  <studio>Studio Bind</studio>
  <status>Continuing</status>
</tvshow>
```

→ Mapeia para `KodiShowNfo(title, plot, genres, year, rating, posterThumb, bannerThumb, fanartThumb)`.

### 2. Regex de thumb de episode

```dart
static final RegExp _episodeThumbPattern = RegExp(
  r'^(?<prefix>S\d+)?E(?<number>\d+)-thumb\.(?<ext>jpg|jpeg|png|webp)$',
  caseSensitive: false,
);
```

Match: `S01E001-thumb.jpg` → `{prefix: 'S01', number: 1, ext: 'jpg'}` (note: 001 → 1, dedup).
Match: `E01-thumb.jpg` → `{prefix: null, number: 1, ext: 'jpg'}`.
Não match: `S01E001.jpg` (sem `-thumb`).

### 3. Pipeline de enrichment no `PauloFlixService.syncContent`

```
Para cada show novo / incompleto:
  1. (NFO) fetch showUrl/tvshow.nfo
     - se 200: parse → monta PauloFlixContent.fromNfo(folderName, serverUrl, nfo)
     - se 404 ou parse fail: log e segue pro passo 2
  2. (Jikan) search/show.name → PauloFlixContent.fromJikan (já existe)
  3. (fallback) PauloFlixContent(folderName, serverUrl) se ambos falharem
```

### 4. URLs de imagem a partir do NFO

Se o `<thumb>` é URL absoluta (`http://...`) → usa direto.
Se é path relativo (`poster.jpg`) → monta `{serverUrl}{thumb}`.
Se múltiplos `<thumb>` com `aspect=poster`/`banner`/`fanart` → escolhe o de maior aspect relevante.

---

## Ordem de implementação

### Fase 0 — Pubspec + schema (1 patch)

**Task 0.1:** Adicionar `xml: ^6.5.0` ao `pubspec.yaml` e rodar `flutter pub get`.
- Validação: `flutter pub deps | grep xml` mostra a versão.

**Task 0.2:** Adicionar coluna `thumbnailUrl` à tabela `paulo_flix_episodes` e bump schema para 6.
- Drift migration: `if (from < 6) await m.addColumn(_db.pauloFlixEpisodes, _db.pauloFlixEpisodes.thumbnailUrl);`
- Validação: `flutter pub run build_runner build --delete-conflicting-outputs` regenera `app_database.g.dart` sem erro.

### Fase 1 — Parser NFO puro (TDD, 4 patches)

**Task 1.1:** Criar `lib/data/services/kodi/kodi_nfo_models.dart` com DTOs imutáveis.
- Classes: `KodiShowNfo`, `KodiMovieNfo`, `KodiSeasonNfo`, `KodiEpisodeNfo`.
- Campos: só os do escopo (title, plot, year, rating, genres, posterThumb, bannerThumb, fanartThumb, episodeNumber, seasonNumber).
- Validação: `flutter analyze` clean.

**Task 1.2:** Test RED — escrever 6 casos de teste do `KodiNfoParser.parseShow(xmlString)`:
- Caso válido completo
- Caso com campos faltando (vazio, só `<title>`)
- Caso XML inválido (lança FormatException)
- Caso com múltiplos `<thumb>` (pega o poster, banner, fanart)
- Caso com `<genre>` múltiplo (retorna List)
- Caso com `<plot>` multilinha (preserva quebras de linha)
- Validação: `flutter test test/data/services/kodi/kodi_nfo_parser_test.dart` → todos FAIL (parser não existe).

**Task 1.3:** Implementar `lib/data/services/kodi/kodi_nfo_parser.dart` com `parseShow`, `parseMovie`, `parseEpisode`.
- Usa `XmlDocument.parse(input)`. Helper `_firstText(node, tag)` que retorna o text do primeiro elemento.
- Helper `_allTexts(node, tag)` para gêneros.
- Helper `_thumbByAspect(node, aspect)` que filtra `<thumb aspect="X">` e pega o primeiro.
- Validação: `flutter test` → todos PASS.

**Task 1.4:** Adicionar métodos `parseMovie` e `parseEpisode` com os mesmos 6 casos. Validar.

### Fase 2 — Enricher HTTP (TDD, 5 patches)

**Task 2.1:** Test RED — `PauloFlixNfoEnricher.fetchShowNfo(folderName, showUrl)` com `MockClient`:
- Mock retorna 200 + XML válido → enricher retorna `KodiShowNfo?` populado
- Mock retorna 404 → retorna null
- Mock retorna 500 → retorna null (não propaga)
- Mock timeout → retorna null
- Validação: `flutter test` → FAIL.

**Task 2.2:** Implementar `PauloFlixNfoEnricher` com `AuthenticatedHttpClient` injetado.
- Método: `Future<KodiShowNfo?> fetchShowNfo(String showUrl)` faz GET `{showUrl}tvshow.nfo`, parse com `KodiNfoParser.parseShow`.
- Try/catch: qualquer exceção (404, 500, timeout, parse) → log + return null.
- Validação: `flutter test` → todos PASS.

**Task 2.3:** Test RED + impl — `fetchEpisodeThumbs(seasonUrl)` retorna `Map<int, String>` (episodeNumber → thumbUrl).
- 4 casos: thumb válido, sem thumb, mistura (alguns episodes com thumb, outros não), listing vazio.
- Validação: implementar regex de thumb + dedup por episode number (pega o primeiro match).

**Task 2.4:** Test RED + impl — `fetchMovieNfo(folderUrl)` similar ao show, com `movie.nfo` ao invés de `tvshow.nfo`.
- Caso extra: movie com `<thumb>` URL absoluta vs path relativo.

**Task 2.5:** Adicionar `fetchSeasonNfo(seasonUrl)` com `season.nfo`. Parse mínimo: só `<season>` e `<plot>`.

### Fase 3 — Integração no PauloFlixService (animes) (3 patches)

**Task 3.1:** Modificar `PauloFlixService.syncContent` para aceitar `PauloFlixNfoEnricher?` opcional.
- Default null (back-compat): enricher desabilitado, comportamento idêntico ao atual.
- Refatorar `_enrichSingleShow` para:
  1. Tentar `enricher.fetchShowNfo(show.url)` → se retornar, criar `PauloFlixContent.fromNfo(...)` e retornar.
  2. Caso contrário, cair no `_enrichSingleShowJikan` (lógica atual movida pra cá).
  3. Caso ambos falhem, retornar placeholder.
- Validação: `flutter analyze` clean. Buildar `flutter test` dos testes existentes (sem regressão).

**Task 3.2:** Modificar `PauloFlixService.fetchShowSeasons` para também detectar `tvshow.nfo` na pasta raiz **e propagar essa info** para o `PauloFlixEpisodeSyncService` (vai usar pra `episodeImageUrl` no batch de episodes).
- Adicionar campo `showNfo` em `PauloFlixShow` (ou criar classe wrapper `PauloFlixShowMetadata`).
- Validação: testes de `PauloFlixEpisodeSyncService` ainda passam.

**Task 3.3:** No `app.dart`, injetar `PauloFlixNfoEnricher` no `Provider<PauloFlixService>`.
- `Provider<PauloFlixNfoEnricher>(create: (_) => PauloFlixNfoEnricher.fromAppDatabase(appDatabase))` no `MultiProvider`.
- `Provider<PauloFlixService>(create: (ctx) => PauloFlixService(... enricher: ctx.read<PauloFlixNfoEnricher>()))`.
- Validação: build OK, `flutter analyze` clean.

### Fase 4 — Integração no PauloFlixMoviesService (2 patches)

**Task 4.1:** Mesmo padrão: `PauloFlixMoviesService.syncContent` aceita `PauloFlixNfoEnricher?` opcional, tenta NFO antes do TMDB.

**Task 4.2:** No `app.dart`, injetar no `PauloFlixMoviesService` via `ctx.read<PauloFlixNfoEnricher>()`.

### Fase 5 — Thumbnail de episode no DB + sync (4 patches)

**Task 5.1:** Atualizar `PauloFlixEpisodeProgressRepository.upsertEpisode` para aceitar `String? thumbnailUrl` (e persistir no DB).
- Adicionar parâmetro `thumbnailUrl` (opcional) ao método.
- No `PauloFlixEpisodesCompanion.update`: incluir `thumbnailUrl: Value(thumbnailUrl)`.
- Re-validar preservação de progresso (não pode sobrescrever `thumbnailUrl` se for null e já tem valor — verificação manual: o `upsertEpisode` atual só atualiza se já existe, mas se o novo `thumbnailUrl` for null, manter o anterior).

**Task 5.2:** Atualizar `PauloFlixEpisodeRecord` e `_toEpisodeDomain` no repo para incluir `thumbnailUrl`.

**Task 5.3:** No `PauloFlixEpisodeSyncService.syncSeasonEpisodes`, chamar `enricher.fetchEpisodeThumbs(seasonUrl)` antes do loop de episodes e passar o mapa para `upsertEpisode`.

**Task 5.4:** No `PauloFlixEpisodeProgressViewModel.scrapingEpisodesForSelected`, expor `thumbnailUrl` no `PauloFlixEpisode` (model de scraping) e no `Episode` (model do player).

### Fase 6 — UI: thumb no card de episode (2 patches)

**Task 6.1:** Adicionar `String? thumbnailUrl` ao `Episode` (model em `lib/domain/models/episode.dart`).
- Se preenchido, `EpisodeGridCard` mostra `Image.network(thumbUrl)` como background (com cache).
- Fallback: gradient atual se `thumbnailUrl == null` ou Image.network falha.
- Adicionar `errorBuilder` ao `Image.network` para fallback gracioso.

**Task 6.2:** Atualizar `_EpisodesList` em `pauloflix_episode_list_screen.dart` para passar `thumbnailUrl` na construção do `Episode` (no `_playEpisode`).

### Fase 7 — Validação final

**Task 7.1:** Smoke test manual:
- Sync PauloFlix animes → verificar que shows com NFO agora tem `description`, `genres`, `score` preenchidos **antes** de chamar Jikan (verificar log `[PauloFlixNfo] Enriched X shows from NFO`).
- Sync PauloFlix Movies → verificar mesma coisa.
- Entrar num anime → verificar que episodes com thumb mostram a imagem no card.
- Rebuild APK release → verificar que `xml: ^6.5.0` está na `pubspec.lock` (sem undefined deps).

**Task 7.2:** `flutter analyze` clean, `flutter test` todos passam, build de release OK.

---

## Verificação manual (smoke test)

1. Abrir o app com servidor PauloFlix rodando.
2. Sincronizar (botão na home de animes PauloFlix).
3. Verificar log: `[PauloFlixNfo] Enriched 12/20 shows from NFO, 8 fell back to Jikan`.
4. Abrir detalhe de anime com NFO → verificar `description` não é o placeholder do Jikan mas sim o plot do NFO (testar com `Mushoku Tensei` que tem tvshow.nfo completo).
5. Abrir lista de episodes → verificar que `S01E001-thumb.jpg` aparece no card do ep 1.
6. Forçar sync sem internet → verificar fallback pra Jikan continua funcionando (animes sem NFO na pasta do servidor devem ser enriquecidos pelo Jikan como hoje).
7. Abrir filme PauloFlix → verificar que `poster.jpg` aparece no card (não mais a imagem do TMDB).

## Riscos & mitigações

| Risco | Impacto | Mitigação |
|-------|---------|-----------|
| NFO mal-formado (XML inválido) quebra o parser | Show inteiro fica sem enrichment | Try/catch em `KodiNfoParser.parseX` — sempre retorna null no erro, fluxo segue pro Jikan |
| `xml` package aumenta APK em ~150KB | Tamanho do APK | Aceitável — `xml` é mais leve que `dart:html` e é o padrão para parse XML em Flutter. Justificativa: NFO é fonte primária, otimização futura com `lxml`-style binary é over-engineering |
| 20+ shows com NFO = 20+ GETs extras por sync | Tempo de sync | NFO é <5KB cada, paralelo via `Future.wait(batchSize: 5)`. Sync total deve cair de ~30s pra ~15s (sem Jikan) |
| Thumbnail de episode 404 em runtime | Card fica vazio | `errorBuilder` no `Image.network` → fallback pro gradient. Sem crash. |
| `poster.jpg` servidor desatualizado vs imagem do Jikan | UI inconsistente entre animes com/sem NFO | Decisão aceita: NFO é fonte primária. Doc no AGENTS.md: "PauloFlix animes com NFO usam imagem do servidor. Animes sem NFO usam Jikan." |
| Drift migration v5→v6 com `addColumn` em DB grande (>1k episodes) | Migração lenta | `addColumn` em SQLite é O(1) (só atualiza schema, não reescreve rows). Verificado: https://www.sqlite.org/lang_altertable.html |
| `AuthenticatedHttpClient` já é wrapper, mas o inner `http.Client` não é fechado | Socket leak em long-lived sync | Adicionar `close()` no `PauloFlixNfoEnricher.dispose()` (provider é descartado no app shutdown) |

## Ordem de execução recomendada

1. Fase 0 → Fase 1 (parser é puro, sem dependência Flutter, testes rodam rápido)
2. Fase 2 → Fase 3 + Fase 4 em paralelo (enricher está pronto, integrar nos 2 services)
3. Fase 5 → Fase 6 (episode thumb no DB + UI)
4. Fase 7 (validação final)

Cada fase termina com `flutter analyze` + `flutter test` antes de avançar. Commits após cada fase.
