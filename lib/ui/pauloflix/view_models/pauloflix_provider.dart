import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/services/kodi/pauloflix_nfo_enricher.dart';
import '../../../data/services/paulo_flix_episode_sync_service.dart';
import '../../../data/services/pauloflix_service.dart';
import '../../../domain/models/pauloflix_content.dart';
import '../../../domain/repositories/pauloflix_repository.dart';
import '../../core/utils/pagination.dart';

enum PauloFlixStatus { initial, loading, loaded, error }

/// Provider da área PauloFlix animes (Fase 3 do plano
/// `docs/DATABASE_REFACTORING.md`).
///
/// Consome `PauloFlixRepository` (Drift) em vez de
/// `PauloFlixDatabaseService` (sqlite3 FFI). O `PauloFlixService`
/// (scraping HTML) ainda existe — este provider delega o sync
/// para ele e usa o repository como persistência.
class PauloFlixProvider extends ChangeNotifier {
  final PauloFlixRepository _repository;

  /// Service de scraping de seasons/episodes. Opcional — quando
  /// `null`, o sync geral **não** dispara o sync de seasons/episodes
  /// (só sincroniza shows do `PauloFlixRepository`). Em produção,
  /// `app.dart` injeta via `withRepositories` (Fase 2). Em
  /// testes/legado, fica `null` e o sync pula o passo de
  /// reconciliação de seasons/episodes.
  final PauloFlixEpisodeSyncService? _episodeSyncService;

  /// Enricher NFO (Fase 3 do plano NFO enrichment) — opcional.
  /// Quando `null` (legacy/tests), `syncContent` usa só Jikan para
  /// enriquecer shows. Quando fornecido (`app.dart` injeta),
  /// `syncContent` tenta NFO primeiro (`tvshow.nfo`) e cai no Jikan
  /// só se NFO ausente/inválido.
  final PauloFlixNfoEnricher? _nfoEnricher;

  /// Ctor padrão — provider sem dependência (cria PauloFlixService
  /// internamente para o sync; usado em testes/legado).
  PauloFlixProvider()
      : _repository = _NullPauloFlixRepository(),
        _episodeSyncService = null,
        _nfoEnricher = null;

  /// Ctor com repository (Fase 3) — usado pelo Provider do app.
  PauloFlixProvider.withRepository(this._repository)
      : _episodeSyncService = null,
        _nfoEnricher = null;

  /// Ctor completo (Fase 2) — injeta o sync service para que
  /// `syncContent` faça o sync completo (shows + seasons + episodes)
  /// em uma única operação.
  PauloFlixProvider.withRepositories({
    required PauloFlixRepository repository,
    required PauloFlixEpisodeSyncService episodeSyncService,
    PauloFlixNfoEnricher? nfoEnricher,
  })  : _repository = repository,
        _episodeSyncService = episodeSyncService,
        _nfoEnricher = nfoEnricher;

  PauloFlixStatus _status = PauloFlixStatus.initial;
  List<PauloFlixContent> _contents = [];
  List<PauloFlixContent> _filteredContents = [];
  String? _errorMessage;
  String _syncProgress = '';
  Timer? _searchDebounce;

  PauloFlixStatus get status => _status;
  List<PauloFlixContent> get contents => _filteredContents;
  String? get errorMessage => _errorMessage;
  String get syncProgress => _syncProgress;
  bool get isSyncing => _status == PauloFlixStatus.loading;

  Future<void> loadContents() async {
    _status = PauloFlixStatus.loading;
    notifyListeners();
    try {
      _contents = await _repository.getAll();
      _filteredContents = _contents;
      _status = PauloFlixStatus.loaded;
    } catch (e) {
      _errorMessage = 'Erro ao carregar conteúdo: $e';
      _status = PauloFlixStatus.error;
    }
    notifyListeners();
  }

  /// Sync com o servidor via `PauloFlixService` (scraping) seguido de
  /// `saveContent` no repository. Mantido o comportamento do service
  /// legado.
  ///
  /// **Fase 2 (Fase 2 do plano de seasons/episodes progress):**
  /// quando o provider foi construído via `withRepositories` (com
  /// episode repository + sync service injetados), o sync também
  /// sincroniza seasons + episodes de cada show processado via
  /// `reconcileSeasonEpisodes`. Resultado: o botão "Sincronizar" da
  /// See All faz TUDO em uma operação — shows, seasons, episodes.
  ///
  /// Para ctors legados (`PauloFlixProvider()` ou `withRepository`),
  /// o sync mostra/episodes só acontece via sync pontual ao entrar
  /// no anime (lazy fallback — `PauloFlixEpisodeProgressViewModel
  /// .loadSeasons`).
  Future<void> syncContent() async {
    _status = PauloFlixStatus.loading;
    _syncProgress = 'Iniciando sincronização...';
    notifyListeners();
    try {
      final sync = await PauloFlixService.syncContent(
        repository: _repository,
        onProgress: (progress) {
          _syncProgress = progress;
          notifyListeners();
        },
        onError: (error) {
          _errorMessage = 'Erro na sincronização: $error';
          _status = PauloFlixStatus.error;
          notifyListeners();
        },
        // Fase 3 (NFO enrichment) — se o enricher foi injetado via
        // `withRepositories`, ele é tentado **antes** do Jikan. Se
        // o servidor PauloFlix tem `tvshow.nfo` na pasta do show,
        // o `PauloFlixContent` é construído a partir do NFO.
        // Quando `null` (legacy/tests), comportamento idêntico ao
        // pré-Fase 3: só Jikan.
        enricher: _nfoEnricher,
        // Fase 2: callback que dispara o sync de seasons/episodes
        // para cada show recém-salvo. Só ativo se o service de
        // episode sync foi injetado (via withRepositories).
        onContentSynced: _episodeSyncService == null
            ? null
            : (content) async {
                final id = content.id;
                if (id == null) return;
                try {
                  // **Fase N+2 — bug fix:** propagar `_nfoEnricher`
                  // para que `reconcileSeasonEpisodes` (e, por
                  // cascata, `syncSeasonEpisodes`) descubram thumbs
                  // de episode, plot de `season.nfo`, e
                  // `poster.jpg`/`fanart.jpg` da pasta da season.
                  // Sem isto, o sync geral via botão "Sincronizar"
                  // da See All passava `enricher: null` → caía no
                  // caminho legado sem NFO enrichment.
                  await _episodeSyncService.reconcileSeasonEpisodes(
                    contentId: id,
                    contentServerUrl: content.serverUrl,
                    enricher: _nfoEnricher,
                  );
                } catch (e) {
                  // Erros em shows individuais são logados mas não
                  // interrompem o sync geral — o callback
                  // `onContentSynced` do service envolve o try/catch
                  // por show, mas deixamos o catch também aqui como
                  // segurança extra.
                  debugPrint(
                    '[PauloFlix] Erro ao sincronizar seasons/episodes '
                    'de ${content.displayName}: $e',
                  );
                }
              },
      );
      if (!sync) {
        _errorMessage = 'Sincronização falhou por motivos desconhecidos.';
        _status = PauloFlixStatus.error;
        notifyListeners();
        return;
      }
      _status = PauloFlixStatus.loaded;
    } catch (e) {
      _errorMessage = 'Erro na sincronização: $e';
      _status = PauloFlixStatus.error;
    }
    notifyListeners();
  }

  void search(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      final searchQuery = query.toLowerCase();
      if (searchQuery.isEmpty) {
        _filteredContents = _contents;
      } else {
        _filteredContents = _contents
            .where(
              (c) =>
                  c.displayName.toLowerCase().contains(searchQuery) ||
                  c.genres.any((g) => g.toLowerCase().contains(searchQuery)),
            )
            .toList();
      }
      notifyListeners();
    });
  }

  /// Busca no banco (Drift) por `displayName` (LIKE + ESCAPE).
  ///
  /// **Quando usar**: telas de busca dedicadas (ex:
  /// [PauloFlixSearchScreen]) que NÃO querem carregar a lista
  /// inteira do provider em memória. Query vazia retorna lista
  /// vazia (não chama SQL).
  ///
  /// **Vantagens sobre o [search] legado (in-memory)**:
  /// - Zero alocação da lista completa do provider.
  /// - Memória constante: só os resultados da query ficam em RAM.
  /// - Funciona bem com milhares de itens (SQLite local é rápido
  ///   para `LIKE` em 10k+ linhas).
  ///
  /// O `search` legado é mantido para outros usos (ex: filtro da
  /// `PauloFlixSeeAllScreen` se aplicável).
  Future<List<PauloFlixContent>> searchByName(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    try {
      return await _repository.searchByName(q);
    } catch (e) {
      debugPrint('searchByName falhou: $e');
      return const [];
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Métodos puros de agrupamento/paginação (testáveis diretamente)
  //
  // São `static` para permitir testes sem mockar ChangeNotifier. Mesma
  // estratégia do `PauloFlixMoviesProvider` e do `applyFilter` da
  // `PauloFlixSearchScreen`. A UI chama esses métodos em
  // `initState`/`didChangeDependencies` (snapshot local) para derivar
  // as seções da tela "Ver Todos".
  // ───────────────────────────────────────────────────────────────────────

  /// Escolhe o anime para o hero banner.
  ///
  /// Critério: maior [PauloFlixContent.score]. Filmes sem score vão pro
  /// final. Desempate por `displayName` alfabético (case-insensitive).
  ///
  /// **Nota:** Diferente de `PauloFlixMoviesProvider.pickFeaturedMovie`,
  /// o `PauloFlixContent` não tem `year` nem `availableMovieCount`, então
  /// o critério é mais simples.
  ///
  /// Retorna `null` se [contents] estiver vazia.
  static PauloFlixContent? pickFeaturedContent(
    List<PauloFlixContent> contents,
  ) {
    if (contents.isEmpty) return null;
    final sorted = [...contents]..sort((a, b) {
      final scoreCmp = (b.score ?? 0).compareTo(a.score ?? 0);
      if (scoreCmp != 0) return scoreCmp;
      return a.displayName
          .toLowerCase()
          .compareTo(b.displayName.toLowerCase());
    });
    return sorted.first;
  }

  /// Agrupa animes pelos [maxGenres] gêneros com mais animes.
  ///
  /// Para cada gênero top, retorna até [perGenre] animes ranqueados por
  /// score descendente. Animes sem score vão pro final do grupo.
  ///
  /// Gêneros com menos de [minPerGenre] animes NÃO aparecem no map
  /// (heurística do caller para evitar carrosséis de 1 filme).
  static Map<String, List<PauloFlixContent>> groupByTopGenres(
    List<PauloFlixContent> contents, {
    int maxGenres = 4,
    int perGenre = 12,
    int minPerGenre = 3,
  }) {
    if (contents.isEmpty) return const {};

    // 1. Conta animes por gênero.
    final genreCount = <String, int>{};
    for (final c in contents) {
      for (final g in c.genres) {
        if (g.isEmpty) continue;
        genreCount[g] = (genreCount[g] ?? 0) + 1;
      }
    }

    // 2. Top N gêneros por contagem.
    final topGenres = genreCount.entries
        .where((e) => e.value >= minPerGenre)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final selected =
        topGenres.take(maxGenres).map((e) => e.key).toList();

    // 3. Para cada gênero top, filtra e ranqueia.
    final result = <String, List<PauloFlixContent>>{};
    for (final g in selected) {
      final filtered = contents.where((c) => c.genres.contains(g)).toList()
        ..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
      result[g] = filtered.take(perGenre).toList();
    }
    return result;
  }

  /// Pagina animes em ordem alfabética para o grid "Todos os Animes".
  ///
  /// Espelha [PauloFlixMoviesProvider.paginateByLetter] mas opera sobre
  /// [PauloFlixContent]. Mesma lógica de sort com sentinela `~` para
  /// garantir que "#" fique no fim.
  static PaginationResult<PauloFlixContent> paginateByLetter(
    List<PauloFlixContent> contents, {
    int perPage = 24,
  }) {
    if (contents.isEmpty) {
      return const PaginationResult<PauloFlixContent>(
        pages: [],
        letterToPageIndex: {},
        availableLetters: [],
      );
    }

    // 1. Ordena alfabeticamente, "#" no fim.
    final sorted = [...contents]..sort((a, b) {
      final aKey = _sortKey(a.displayName);
      final bKey = _sortKey(b.displayName);
      final cmp = aKey.compareTo(bKey);
      if (cmp != 0) return cmp;
      return a.displayName
          .toLowerCase()
          .compareTo(b.displayName.toLowerCase());
    });

    // 2. Pagina.
    final pages = <List<PauloFlixContent>>[];
    for (var i = 0; i < sorted.length; i += perPage) {
      final end = i + perPage > sorted.length ? sorted.length : i + perPage;
      pages.add(sorted.sublist(i, end));
    }

    // 3. Mapeia letra → primeira página onde aparece.
    final letterToPageIndex = <String, int>{};
    final availableLetters = <String>[];
    for (var i = 0; i < pages.length; i++) {
      for (final c in pages[i]) {
        final letter = _normalizeFirstChar(c.displayName);
        if (!letterToPageIndex.containsKey(letter)) {
          letterToPageIndex[letter] = i;
          availableLetters.add(letter);
        }
      }
    }
    availableLetters.sort((a, b) {
      if (a == '#') return 1;
      if (b == '#') return -1;
      return a.compareTo(b);
    });

    return PaginationResult<PauloFlixContent>(
      pages: pages,
      letterToPageIndex: letterToPageIndex,
      availableLetters: availableLetters,
    );
  }

  /// Helper privado: normaliza o primeiro caractere de [name].
  static String _normalizeFirstChar(String name) {
    if (name.isEmpty) return '#';
    final first = name[0].toUpperCase();
    final isLetter = RegExp(r'^[A-Z]$').hasMatch(first);
    return isLetter ? first : '#';
  }

  /// Helper privado: retorna a chave de ordenação. "#" vira "~" (0x7E).
  static String _sortKey(String name) {
    final first = _normalizeFirstChar(name);
    return first == '#' ? '~' : first;
  }

  void clearSearch() {
    _filteredContents = _contents;
    notifyListeners();
  }

  PauloFlixContent? getByMalId(int malId) {
    try {
      return _contents.firstWhere((c) => c.malId == malId);
    } catch (e) {
      debugPrint('getByMalId: $malId not found — $e');
      return null;
    }
  }

  bool isAvailableOnPauloFlix(String animeName) {
    return _contents.any(
      (c) =>
          c.displayName.toLowerCase() == animeName.toLowerCase() ||
          c.folderName.toLowerCase() == animeName.toLowerCase(),
    );
  }
}

/// Fallback no-op para o ctor sem dependência. Mantém PauloFlixProvider
/// funcionando em testes/legado até que o app use `withRepository`.
class _NullPauloFlixRepository implements PauloFlixRepository {
  @override
  Future<List<PauloFlixContent>> getAll() async => [];
  @override
  Future<List<PauloFlixContent>> searchByName(String query) async => [];
  @override
  Future<PauloFlixContent?> getByFolderName(String folderName) async => null;
  @override
  Future<PauloFlixContent?> getByMalId(int malId) async => null;
  @override
  Future<void> saveContent(PauloFlixContent content) async {}
  @override
  Future<void> saveBatch(List<PauloFlixContent> contents) async {}
  @override
  Future<void> markAsUnavailable(String folderName) async {}
  @override
  Future<Map<String, int>> getStats() async => {
    'total': 0,
    'available': 0,
    'withMetadata': 0,
  };
  @override
  Stream<List<PauloFlixContent>> watch() => const Stream.empty();
}
