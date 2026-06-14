# 🎬 PauloFlix Movies — Nova Área de Filmes com TMDB

## Visão Geral

Área dedicada a filmes no GoAnime Mobile, espelhando o PauloFlix de animes, mas com:

- **Servidor de arquivos**: `http://100.95.105.113:8300/movies/` (PauloFlix — file server com HTML listings)
- **Provedor de metadados**: The Movie Database (TMDB) API v3 — https://www.themoviedb.org/?language=pt-BR
- **Banco local**: SQLite (`pauloflix_movies.db`), separado do banco de animes
- **Toggle**: pill no action bar do `MainNavigationScreen` para alternar entre Animes e Filmes
- **Sincronização**: primeira inicialização completa + manual via botão refresh

## Decisões de Design (já validadas com o usuário)

1. **Toggle no menu superior** (não bottom nav) — duas pills "📺 Animes" / "🎬 Filmes" no AppBar
2. **TMDB API key v3** — input do usuário em Settings (SharedPreferences), carregada no boot
3. **Filmes + Coleções** — sub-pastas também são tratadas como filmes (e.g. "Coleção Harry Potter")
4. **Player reusado** — `ModernVideoPlayerScreen` com 1 episódio (sem AniSkip para filmes)

## Estrutura de Pastas do PauloFlix Movies

```
/movies/
  ├── A Origem (2010)/                    ← Filme individual
  │   ├── A Origem (2010) 1080p - xxx.mp4
  │   └── *.srt (legenda)
  ├── Amadeus/
  │   └── Amadeus.1984.Directors.Cut....mkv
  └── Coleção Harry Potter 2001-2011/     ← Coleção
      ├── Harry Potter e a Pedra Filosofal 2001/
      └── ...
```

**Lógica de detecção**:
- Tem `.mkv`/`.mp4` direto → **filme individual** (pega o primeiro)
- Tem apenas sub-pastas com `.mkv`/`.mp4` dentro → **coleção** (banner + sub-filmes)
- `.srt`/`.jpg`/`.txt` são ignorados

## Arquivos

### Novos (13)

| Camada | Arquivo | Função |
|---|---|---|
| Models | `lib/models/tmdb_models.dart` | `TmdbMovie`, `TmdbGenre`, helpers de URL |
| Models | `lib/models/pauloflix_movie.dart` | Modelo unificado (filme OU coleção) |
| Models | `lib/models/pauloflix_movie_item.dart` | Filme único (dentro de coleção ou isolado) |
| Services | `lib/services/tmdb_service.dart` | Cliente TMDB + cache 30min + throttle 25 req/s |
| Services | `lib/services/pauloflix_movies_service.dart` | HTML scraping + limpeza de nomes + detecção coleção |
| Services | `lib/services/pauloflix_movies_database_service.dart` | SQLite `pauloflix_movies.db` |
| Services | `lib/services/api_key_settings_service.dart` | Persiste `tmdb_api_key` em SharedPreferences |
| Providers | `lib/providers/pauloflix_movies_provider.dart` | Espelha `PauloFlixProvider` |
| Widgets | `lib/widgets/pauloflix_movies_badge.dart` | Badge vermelho cinema |
| Widgets | `lib/widgets/pauloflix_movies_section.dart` | Carrossel estilo Netflix |
| Widgets | `lib/widgets/content_type_selector.dart` | Pill "Animes" / "Filmes" no AppBar |
| Screens | `lib/screens/pauloflix_movies_home_screen.dart` | Grid + busca + sync |
| Screens | `lib/screens/pauloflix_movie_detail_screen.dart` | Filme OU lista de coleção |

### Modificados (3)

- `lib/main.dart` — registra `PauloFlixMoviesProvider` + carrega TMDB key no boot
- `lib/screens/main_navigation_screen.dart` — toggle no AppBar + body dinâmico (estado `_contentType`)
- `lib/screens/settings_screen.dart` — campo de input da TMDB API key

## Schema do Banco

```sql
CREATE TABLE pauloflix_movies (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  folderName TEXT NOT NULL UNIQUE,   -- nome da pasta no servidor
  displayName TEXT NOT NULL,         -- nome limpo para exibição
  serverUrl TEXT NOT NULL,           -- URL completa da pasta
  imageUrl TEXT,                     -- poster TMDB (w500)
  bannerUrl TEXT,                    -- backdrop TMDB (w1280)
  description TEXT,                  -- overview TMDB
  score REAL,                        -- vote_average TMDB (0-10)
  genres TEXT,                       -- comma-separated
  releaseDate TEXT,                  -- TMDB release_date (YYYY-MM-DD)
  runtime INTEGER,                   -- minutos
  year INTEGER,                      -- extraído do nome
  tmdbId INTEGER,                    -- TMDB ID
  isCollection INTEGER NOT NULL DEFAULT 0,
  availableMovieCount INTEGER DEFAULT 0,  -- quantos sub-filmes (coleção)
  lastSynced TEXT NOT NULL,
  isAvailable INTEGER NOT NULL DEFAULT 1
);
```

## TMDB Service — Endpoints

```
GET /search/movie?api_key=KEY&query=TITLE&language=pt-BR&year=YEAR&include_adult=false
GET /movie/{id}?api_key=KEY&language=pt-BR
GET /configuration?api_key=KEY  (para image_base_url)
```

**Image base URL**: `https://image.tmdb.org/t/p/{size}{path}`
- Tamanhos usados: `w500` (poster), `w1280` (backdrop), `original` (fallback)

**Rate limit**: 50 req/s pelo TMDB; throttlar para 25 req/s por segurança (mesmo padrão dos animes).

## Algoritmo de Limpeza de Nomes (CRÍTICO)

Os nomes no `/movies/` são bem bagunçados:
```
"A Origem (2010) 1080p - 210GJI.mp4"
"Amadeus.1984.Directors.Cut.1080p.BluRay.H264.AAC-RARBG.mkv"
"Deadpool.and.Wolverine.2024.1080p.AMZN.WEBRip.1400MB.DD5.1.x264-GalaxyRG[TGx]"
"Capitao.America.O.Primeiro.Vingador.2011.1080p-WOLVERDONFILMES.COM"
```

`cleanMovieName(String rawName)` faz 4 passes:

1. **Remove extensão**: `.mkv`/`.mp4`/`.avi`/`.webm`
2. **Remove ano entre parênteses/colchetes**: `(2010)`, `[1985]`
3. **Remove tags em ordem** (case-insensitive):
   - **Qualidade**: 1080p, 720p, 480p, 2160p, 4K, FULLHD, BluRay, BRRip, BDRip, WEB-DL, WEBRip, WEB, HDTV, HDRip, DVDRip, Open.Matte, Directors.Cut, Extended, Remastered, Remasterizada
   - **Codecs**: x264, x265, HEVC, H264, H265, 10bit, AVC, AV1, Opus
   - **Áudio**: DUAL, Dublado, Legendado, Dual.Áudio, 5.1, 7.1, DDP5.1, AAC, AC3, DD5.1, Dual.Audio
   - **Grupos**: WWW.BLUDV.COM, BLUDV.COM, wolverdonfilmes.com, WOLVERDONFILMES.COM, GalaxyRG, YTS.MX, KONTRAST, Alan_680, AndreTPF, LAPUMiA, SF, Zero00, FG4LL4RD0, RARBG, TGx, TO, ThePirateFilmes, The.Pirate.Filmes
4. **Normaliza**: múltiplos espaços → 1 espaço, remover pontos finais, trim

**Saídas esperadas**:
```
"A Origem"
"Amadeus"
"Deadpool and Wolverine"
"Capitão América O Primeiro Vingador"
```

**Regex para extrair ano (passado pra busca TMDB)**: `\b(?:19|20)\d{2}\b`

## Detecção Filme vs Coleção

```dart
Future<PauloFlixMovieRaw> inspectFolder(folderName, folderUrl) async {
  final links = (await fetchHtml(folderUrl)).links;

  final videoFiles = links.where((l) =>
    videoExtensions.any((ext) => l.name.toLowerCase().endsWith(ext))
  ).toList();

  final subFolders = links.where((l) =>
    l.href.endsWith('/') && !l.href.contains('..')
  ).toList();

  if (videoFiles.isNotEmpty) {
    return PauloFlixMovieRaw.single(
      folderName: folderName,
      folderUrl: folderUrl,
      videoFile: videoFiles.first,
      year: extractYear(folderName),
      cleanedName: cleanMovieName(videoFiles.first.name),
    );
  }

  if (subFolders.isNotEmpty) {
    return PauloFlixMovieRaw.collection(
      folderName: folderName,
      folderUrl: folderUrl,
      subfolders: subFolders,
    );
  }

  return PauloFlixMovieRaw.empty(folderName: folderName, folderUrl: folderUrl);
}
```

## Fluxo da API Key TMDB

1. Usuário abre **Settings** → cola a key v3 → Salva
2. `ApiKeySettingsService` persiste em SharedPreferences (`tmdb_api_key`)
3. `TmdbService.setApiKey(...)` carrega para uso em memória
4. `PauloFlixMoviesProvider.syncContent()` checa `TmdbService.isConfigured`:
   - `false` → erro: "Configure a chave da API do TMDB em Configurações → API Keys"
   - `true` → prossegue
5. Se TMDB retornar 401 → invalida cache, pede reconfiguração
6. Link externo nas Settings: https://www.themoviedb.org/settings/api

## Fluxo do Toggle (main_navigation_screen)

```
Estado: ContentType { anime, movie }
AppBar actions: [Search] [Animes|Filmes toggle] [Watchlist] [Settings]
Body (IndexedStack):
  if _contentType == anime → HomeScreen (atual, sem mudança)
  if _contentType == movie → PauloFlixMoviesHomeScreen
IndexedStack inferior: Search, Watchlist, Downloads, Settings (intactos)
```

**Estado default**: `_contentType = ContentType.anime`

**Mudança importante**: sincronização automática do PauloFlix Movies só dispara no `_contentType == movie` no `initState` do `PauloFlixMoviesHomeScreen` (lazy load — evita requisições desnecessárias).

## Ordem de Implementação

1. **Models** — `tmdb_models.dart`, `pauloflix_movie.dart`, `pauloflix_movie_item.dart`
2. **Services de infra** — `api_key_settings_service.dart`, `tmdb_service.dart`
3. **Service principal** — `pauloflix_movies_service.dart` (limpeza de nomes + detecção coleção)
4. **Database** — `pauloflix_movies_database_service.dart`
5. **Provider** — `pauloflix_movies_provider.dart`, registrar no `main.dart`
6. **Settings** — campo TMDB key em `settings_screen.dart`
7. **Widgets** — `pauloflix_movies_badge.dart`, `pauloflix_movies_section.dart`, `content_type_selector.dart`
8. **Screens** — `pauloflix_movies_home_screen.dart`, `pauloflix_movie_detail_screen.dart`
9. **Integration** — `main_navigation_screen.dart` (toggle) + `main.dart` (provider)
10. **Verificação** — `flutter analyze` + `flutter test` + smoke test
11. **Documentação** — atualizar `docs/Services.md`, `docs/Models.md`, `docs/APIs.md`, `AGENTS.md`

## Verificação

### Funcional
- [ ] Primeira abertura: detecta TMDB não configurado → banner com CTA
- [ ] Após configurar → primeira sincronização (200+ filmes cobertos)
- [ ] Filmes em grid com posters TMDB
- [ ] Coleções com banner custom + sub-filmes clicáveis
- [ ] Filme individual → player direto (reusa `ModernVideoPlayerScreen`)
- [ ] Coleção → tela de detalhe com sub-filmes
- [ ] Busca filtra em tempo real
- [ ] Sync manual via botão refresh
- [ ] Filmes removidos do servidor → `isAvailable = 0`
- [ ] Funciona em TV (grid adaptativo, D-pad navigation)

### Técnica
- [ ] `flutter analyze` sem novos warnings
- [ ] `flutter test` passa
- [ ] Banco `pauloflix_movies.db` em `getApplicationDocumentsDirectory()`
- [ ] Rate limit TMDB respeitado (throttle 25 req/s)
- [ ] Cache em memória para mesma query (mesmo padrão JikanService)
- [ ] Logs com prefixo `[PauloFlix Movies]` e `[TmdbService]`

## Comandos de Validação

```bash
cd C:/Users/pr02n/developer/goanime-mobile
flutter pub get
flutter analyze
flutter test
flutter run -d <device>
```

## Riscos & Mitigações

| Risco | Mitigação |
|---|---|
| TMDB 401 sem API key | Validação no salvamento; sync bloqueado se `!TmdbService.isConfigured` |
| Nomes bagunçados de pastas | Algoritmo de 4 passes + extração de ano + tentar variações |
| Coleções com sub-pastas bagunçadas | Mesma limpeza aplicada recursivamente (1 nível) |
| Rate limit TMDB | Cache em memória 30min + throttle 25 req/s |
| Colisões `displayName` | `folderName` UNIQUE no banco + `tmdbId` como secundário |
| Banco separado de animes | Decisão intencional — backup independente, menor risco de schema-drift |

## Fora de Escopo (intencional)

- Sem trailer/clipes (não usa `/movie/{id}/videos`)
- Sem credits (cast/crew)
- Sem reviews
- Sem filtro por gênero na home
- Sem watchlist de filmes
- Sem download offline de filmes
- Sem persistência de "continuar assistindo" para filmes
- Toggle afeta apenas o body principal; telas Search/Watchlist/Downloads/Settings seguem focadas em animes

## Convenções Seguidas

- ✅ Comentários em português
- ✅ `package:provider` para state management (mesmo padrão)
- ✅ `sqlite3` para banco (mesmo padrão)
- ✅ `NetflixCard` + `NetflixCarousel` reusados (não criar widgets paralelos)
- ✅ `lib/models/*_models.dart` para agrupar modelos por API
- ✅ `service.dart` com `static` helpers (mesmo padrão `PauloFlixService`)
- ✅ `ChangeNotifier` providers, não Riverpod/Bloc
- ✅ `debugPrint` com prefixo `[PauloFlix Movies]` para rastreio de logs
- ✅ Sem refactor paralelo do PauloFlix de animes (foco só no que foi pedido)
