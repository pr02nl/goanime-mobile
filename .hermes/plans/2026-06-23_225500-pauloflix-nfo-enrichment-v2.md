# PauloFlix — NFO Enrichment V2: Season NFO + Encoding Fixes

> **For Hermes:** Use subagent-driven-development to implement this plan. Each Fase is 1 subagent com ownership de arquivo único, dispatched em paralelo (4 subagents no mesmo batch).

**Goal:** (1) Adicionar parse de `season.nfo` (que existe em cada pasta de season) e `S01E001.nfo` (que existe em cada episode) para popular `description` da season e `plot` do episode —填补 gaps que só o TMDB/Jikan cobriam. (2) Corrigir 3 bugs de encoding que fazem acentos do português virarem `?` ou caracteres inválidos.

**Architecture:** Reusa o `KodiNfoParser` existente (Fase 1) — só adiciona `parseSeasonNfo` e enriquece `parseEpisode` para retornar `plot` também. Fix de encoding é troca de `Uri.decodeComponent` → `safeDecodeComponent` + detecção de charset em HTML listings.

**Tech Stack:** Mesmos pacotes. Sem novas dependências.

---

## Decisões validadas

✅ **Execução:** 4 fixes em paralelo (1 subagent por Fase), ownership estrito de arquivo.
✅ **Jikan/TMDB:** Mantidos como fallback. NFO primário (status quo).
✅ **Season NFO:** Parsear `season.nfo` que tem `season/plot/poster` — popula `PauloFlixSeasonRecord.description`.
✅ **Episode NFO:** Parsear `S01E001.nfo` que tem `season/episode/title/plot` — popula `PauloFlixEpisodeRecord.description` (campo novo).
✅ **Encoding:** 3 fixes separados (HTML charset detection + safeDecodeComponent + replace onde falta).

---

## Estrutura de arquivos

### Fase 8 — Encoding fix (3 sub-files, 1 subagent)
**Ownership:** `lib/data/services/pauloflix_service.dart`, `lib/data/services/pauloflix_movies_service.dart`, `lib/data/services/paulo_flix_episode_sync_service.dart`

- `lib/data/services/pauloflix_service.dart` — replace `Uri.decodeComponent` → `safeDecodeComponent` em `fetchAllShows` e `fetchShowSeasons`
- `lib/data/services/pauloflix_movies_service.dart` — já usa `safeDecodeComponent`; **faltam testes** + adicionar charset detection em `_parseLinks`
- `lib/data/services/paulo_flix_episode_sync_service.dart` — já usa `safeDecodeComponent`; **faltam testes** + charset detection

### Fase 9 — Season NFO + Episode NFO parsing (1 subagent)
**Ownership:** `lib/data/services/kodi/kodi_nfo_parser.dart`, `lib/data/services/kodi/kodi_nfo_models.dart`, `test/data/services/kodi/kodi_nfo_parser_test.dart`

- Adicionar método `KodiNfoParser.parseSeasonNfo(xmlBody)` (root `<season>` com campos `season/plot/poster`)
- Enriquecer `KodiNfoParser.parseEpisode` para retornar `plot` além de `title/season/episode`
- Adicionar campo `KodiSeasonNfo.plot: String?` e `KodiEpisodeNfo.plot: String?`
- 6+ testes novos cobrindo season e episode plot

### Fase 10 — Season NFO integration (1 subagent)
**Ownership:** `lib/data/services/kodi/pauloflix_nfo_enricher.dart`, `lib/data/services/paulo_flix_episode_sync_service.dart`, `lib/data/repositories/paulo_flix_episode_progress_repository_impl.dart`, `lib/domain/repositories/paulo_flix_episode_progress_repository.dart`, `lib/domain/models/paulo_flix_season_record.dart`, `lib/domain/models/paulo_flix_episode_record.dart`

- Adicionar `fetchSeasonNfo` método já existe no enricher — só falta INTEGRAÇÃO no `syncSeasonEpisodes` (popular `description` da season)
- Adicionar `fetchEpisodeNfo(seasonUrl, episodeNumber)` para pegar NFO específico de um episode → popular `description` do episode
- Adicionar campo `description: text().nullable()` em `PauloFlixSeasons` (migration v6→v7) e `description: text().nullable()` em `PauloFlixEpisodes` (extension da v6)
- Bump `schemaVersion` para 7
- Adicionar `seasonDescription: String?` no `PauloFlixSeasonRecord` model
- Adicionar `description: String?` no `PauloFlixEpisodeRecord` model (não confundir com o campo `plot` da NFO — usa o mesmo nome `description` que Jikan retorna)
- Atualizar `_toSeasonDomain` e `_toEpisodeDomain` no repo
- Adicionar `seasonDescription: String?` no `upsertSeason` e `description: String?` no `upsertEpisode`

### Fase 11 — Manual `.g.dart` patch + DB migration v6→v7 (1 subagent)
**Ownership:** `lib/core/database/app_database.dart`, `lib/core/database/app_database.g.dart`, `lib/core/database/tables/paulo_flix_seasons.dart`, `lib/core/database/tables/paulo_flix_episodes.dart`

- Adicionar `description: text().nullable()` em `PauloFlixSeasons` (tabela)
- Confirmar campo em `PauloFlixEpisodes` (Fase 5 já adicionou `thumbnailUrl`; Fase 10 precisa de `description` também)
- Bump `schemaVersion` 6 → 7
- Adicionar `if (from < 7)` no `onUpgrade` com `addColumn` para `paulo_flix_seasons.description` e `paulo_flix_episodes.description`
- Editar `app_database.g.dart` manualmente (8 patches por coluna, mesmo padrão da Fase 0/6):
  1. `static const VerificationMeta _descriptionMeta`
  2. `late final GeneratedColumn<String> description = GeneratedColumn<String>(...)` (nullable)
  3. List `$columns` em `$PauloFlixSeasonsTable` e `$PauloFlixEpisodesTable`
  4. Bloco `validateIntegrity` para `description` (nullable, sem `missing`)
  5. `map()` no `$PauloFlixSeasonsTable` e `$PauloFlixEpisodesTable` (adicionar `description: ...`)
  6. Data class `PauloFlixSeason` e `PauloFlixEpisode` field + constructor
  7. `toColumns()` e `toCompanion()` no Data class
  8. `fromJson()` e `toJson()` no Data class
  9. `copyWith()` e `copyWithCompanion()` no Data class
  10. `==` operator no Data class
  11. Companion class: field, constructor, `.insert()`, `custom()`, `copyWith()`, `toColumns()`, `toString()`

---

## Algoritmos críticos

### Encoding Fix #1: HTML charset detection (nginx autoindex)

O nginx autoindex tipicamente retorna `<meta charset="utf-8">` no `<head>`. O pacote `html` parser assume UTF-8 por padrão. Solução:

```dart
// Antes:
final document = html_parser.parse(response.body);

// Depois:
String htmlContent = response.body;
// Detecta charset em ordem de preferência:
// 1. <meta charset="..."> no <head>
// 2. Content-Type header do response
// 3. Fallback UTF-8 (default do HTTP/1.1)
final detectedCharset = _detectCharset(htmlContent, response.headers['content-type']);
if (detectedCharset != null && detectedCharset.toLowerCase() != 'utf-8') {
  // Re-decodifica: o html_parser já leu como UTF-8, mas se o server
  // mandou Latin-1, vai estar errado. Workaround: re-decodifica a string
  // e cria novo document.
  // IMPORTANTE: charset do XML declaration > meta tag > Content-Type header
  htmlContent = utf8.decode(
    latin1.encode(htmlContent), // sim, encode-then-decode é feio mas funciona
    allowMalformed: true,
  );
}
final document = html_parser.parse(htmlContent);
```

### Encoding Fix #2: safeDecodeComponent everywhere

`Uri.decodeComponent` lança `ArgumentError` em `%XY` inválido. Já existe `safeDecodeComponent` em `PauloFlixMoviesService` e `PauloFlixEpisodeSyncService`. **Falta em `PauloFlixService`**.

```dart
// Em PauloFlixService, adicionar helper local (ou importar do MoviesService):
static String safeDecodeComponent(String input) {
  if (input.isEmpty) return input;
  try {
    return Uri.decodeComponent(input);
  } on ArgumentError {
    final buf = StringBuffer();
    final pattern = RegExp(r'%([0-9A-Fa-f]{2})');
    int lastEnd = 0;
    for (final match in pattern.allMatches(input)) {
      buf.write(input.substring(lastEnd, match.start));
      buf.write(Uri.decodeComponent('%${match.group(1)!}'));
      lastEnd = match.end;
    }
    buf.write(input.substring(lastEnd));
    return buf.toString();
  } catch (_) {
    return input;
  }
}
```

### Season NFO format (Kodi standard)

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<season>
  <seasonnumber>1</seasonnumber>
  <plot>The story begins...</plot>
  <thumb>season01.jpg</thumb>
  <title>Season 1</title>
</season>
```

Note: o root é `<season>` (não `<seasonnumber>` — esse é só um campo). Diferente do `tvshow.nfo` (root `<tvshow>`).

### Episode NFO format (Kodi standard)

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<episodedetails>
  <season>1</season>
  <episode>1</episode>
  <title>Pilot</title>
  <plot>The story begins...</plot>
  <thumb>S01E001-thumb.jpg</thumb>
  <aired>2024-01-01</aired>
  <runtime>24</runtime>
</episodedetails>
```

Já temos `parseEpisode` (Fase 1) mas só retorna `({int? season, int? episode, String? title})`. Fase 9 enriquece para adicionar `plot`.

---

## Ordem de implementação

### Fase 8 — Encoding fixes (1 subagent)
**Owner único:** `lib/data/services/pauloflix_service.dart`, `lib/data/services/pauloflix_movies_service.dart`, `lib/data/services/paulo_flix_episode_sync_service.dart`

**Tasks:**
1. Adicionar `safeDecodeComponent` como helper estático em `PauloFlixService` (ou importar do MoviesService — escolha do subagent).
2. Substituir `Uri.decodeComponent` por `safeDecodeComponent` em `fetchAllShows` e `fetchShowSeasons`.
3. Adicionar charset detection em `_parseLinks` do `PauloFlixMoviesService` e do `PauloFlixEpisodeSyncService`.
4. Adicionar testes para encoding (já existem no `kodi_nfo_parser_test.dart`; faltam para `safeDecodeComponent` standalone).

### Fase 9 — KodiNfoParser enrichment (1 subagent)
**Owner único:** `lib/data/services/kodi/kodi_nfo_parser.dart`, `lib/data/services/kodi/kodi_nfo_models.dart`, `test/data/services/kodi/kodi_nfo_parser_test.dart`

**Tasks:**
1. Adicionar campo `plot: String?` em `KodiSeasonNfo` e `KodiEpisodeNfo` DTOs.
2. Adicionar método `KodiNfoParser.parseSeasonNfo(xmlBody)` (root `<season>`).
3. Enriquecer `KodiNfoParser.parseEpisode` para retornar `plot` no record Dart 3.
4. Atualizar `typedef EpisodeNfo` para incluir `plot`.
5. Adicionar 6+ testes cobrindo:
   - season.nfo válido (todos os campos)
   - season.nfo com só `<seasonnumber>` (mínimo)
   - season.nfo com XML inválido → null
   - season.nfo com root errado (`<tvshow>`) → null
   - episode.nfo com `<plot>` longo multilinha
   - episode.nfo com CDATA no plot

### Fase 10 — Schema v6→v7 + integration (1 subagent)
**Owner único:** 5 arquivos (ver acima)

**Tasks:**
1. Adicionar `description: text().nullable()` em `PauloFlixSeasons` table.
2. Adicionar `description: text().nullable()` em `PauloFlixEpisodes` table.
3. Bump `schemaVersion` 6 → 7 no `app_database.dart`.
4. Adicionar `if (from < 7)` no `onUpgrade` com `addColumn` para ambos.
5. Adicionar `seasonDescription: String?` no `PauloFlixSeasonRecord`.
6. Adicionar `description: String?` no `PauloFlixEpisodeRecord`.
7. Atualizar `_toSeasonDomain` e `_toEpisodeDomain` no repo.
8. Adicionar `seasonDescription: String?` no `upsertSeason` contract + impl.
9. Adicionar `description: String?` no `upsertEpisode` contract + impl.
10. No `PauloFlixEpisodeSyncService.syncSeasonEpisodes`:
    - Chamar `enricher.fetchSeasonNfo(seasonUrl)` ANTES do `upsertSeason` → popular `seasonDescription`.
    - Para cada episode, chamar `enricher.fetchEpisodeNfo(seasonUrl, episodeNumber)` → popular `description`.
    - **OTIMIZAÇÃO:** em vez de 1 GET por episode (N requests), fazer 1 GET do listing da season e parsear todos os `S01E001.nfo` de uma vez.
11. Adicionar método `fetchEpisodeNfo(seasonUrl, episodeNumber)` no enricher OU `fetchEpisodeNfos(seasonUrl)` que retorna `Map<int, String>` (episode → description).

### Fase 11 — Manual `.g.dart` patches (1 subagent)
**Owner único:** `lib/core/database/app_database.g.dart`

**Tasks:**
1. Adicionar `_descriptionMeta` + `description` field em `$PauloFlixSeasonsTable`.
2. Adicionar na lista `$columns` de `$PauloFlixSeasonsTable`.
3. Bloco `validateIntegrity` para `description` em `$PauloFlixSeasonsTable`.
4. `map()` em `$PauloFlixSeasonsTable` (adicionar `description: ...`).
5. Adicionar `description` field no data class `PauloFlixSeason`.
6. Constructor do `PauloFlixSeason` (param `this.description`).
7. `toColumns()`, `toCompanion()`, `fromJson()`, `toJson()` em `PauloFlixSeason`.
8. `copyWith()` e `copyWithCompanion()` em `PauloFlixSeason`.
9. `==` operator em `PauloFlixSeason`.
10. Companion class `PauloFlixSeasonsCompanion` (field, ctor, `.insert()`, `custom()`, `copyWith()`, `toColumns()`, `toString()`).
11. Repetir 1-10 para `PauloFlixEpisode` (já tem `thumbnailUrl` da Fase 0, só adicionar `description`).

---

## Validação

Após cada Fase:
- `flutter analyze` — 0 issues novos
- `flutter test test/data/services/kodi/` — X/X passing (41 + 6 novos = 47 esperados)

Após Fase 11 (final):
- `flutter test` (full suite) — mesmas 8 falhas pré-existentes
- Smoke test em device real:
  - Sincronizar animes → ver season com `description` (sem NFO = null, com NFO = texto)
  - Sincronizar animes → ver episode com `description` (sem NFO = null, com NFO = plot)
  - Sincronizar com pasta com acentos (ex: "Ação", "Pródigo") → ver texto correto, sem `?`

---

## Riscos & Mitigações

| Risco | Impacto | Mitigação |
|-------|---------|-----------|
| N+1 GET requests (1 por episode) | Sync lento | Otimização: 1 GET do listing + parse inline dos `S01E001.nfo` |
| Charset detection falha | Acentos quebrados | Fallback UTF-8 (default HTTP/1.1). Log do charset detectado. |
| `safeDecodeComponent` lento | Sync marginal mais lento | Aceitável — 30+ ms vs 5+ ms, irrelevante. |
| Manual `.g.dart` patch erro | Build quebrado | Usar checklist de 11 itens (Fase 11). Validar com `flutter analyze`. |

## One-Shot Recipe

```python
delegate_task(goal="Fase 8: encoding fixes", context=..., toolsets=["file", "terminal"], role="leaf")
delegate_task(goal="Fase 9: parser enrichment", context=..., toolsets=["file", "terminal"], role="leaf")
delegate_task(goal="Fase 10: schema v6→v7 + integration", context=..., toolsets=["file", "terminal"], role="leaf")
delegate_task(goal="Fase 11: manual .g.dart patches", context=..., toolsets=["file", "terminal"], role="leaf")
# Validar todos
```
