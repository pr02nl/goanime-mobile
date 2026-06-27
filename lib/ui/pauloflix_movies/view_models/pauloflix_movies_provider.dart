import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/services/kodi/pauloflix_nfo_enricher.dart';
import '../../../data/services/pauloflix_movies_service.dart';
import '../../../domain/models/pauloflix_movie.dart';
import '../../../domain/repositories/pauloflix_movies_repository.dart';
import '../../core/utils/pagination.dart';

enum PauloFlixMoviesStatus { initial, loading, loaded, error }

/// Provider da área de filmes PauloFlix (Fase 3 do plano
/// `docs/DATABASE_REFACTORING.md`).
///
/// Consome `PauloFlixMoviesRepository` (Drift) em vez de
/// `PauloFlixMoviesDatabaseService` (sqlite3 FFI). O `TmdbService`
/// e o `PauloFlixMoviesService` (scraping HTML) continuam usados
/// pelo `syncContent`.
class PauloFlixMoviesProvider extends ChangeNotifier {
  final PauloFlixMoviesRepository _repository;

  /// Enricher NFO (Fase 4 do plano NFO enrichment) — opcional. Quando
  /// `null` (legacy/tests), `syncContent` usa só TMDB para enriquecer
  /// filmes. Quando fornecido (`app.dart` injeta via `withServices`),
  /// `syncContent` tenta NFO primeiro (`movie.nfo`) e cai no TMDB
  /// só se NFO ausente/inválido.
  final PauloFlixNfoEnricher? _nfoEnricher;

  /// Ctor padrão (compat) — usa um no-op repository.
  PauloFlixMoviesProvider()
    : _repository = _NullPauloFlixMoviesRepository(),
      _nfoEnricher = null;

  /// Ctor com repository + services opcionais (testes).
  ///
  /// **Fase 4 (NFO enrichment):** [nfoEnricher] é passado pro
  /// `PauloFlixMoviesService.syncContent` para que tente NFO
  /// (`movie.nfo`) antes do TMDB.
  PauloFlixMoviesProvider.withServices({
    required PauloFlixMoviesRepository repository,
    PauloFlixNfoEnricher? nfoEnricher,
  }) : _repository = repository,
       _nfoEnricher = nfoEnricher;

  PauloFlixMoviesStatus _status = PauloFlixMoviesStatus.initial;
  List<PauloFlixMovie> _contents = [];
  List<PauloFlixMovie> _filteredContents = [];
  String? _errorMessage;
  String _syncProgress = '';
  Timer? _searchDebounce;

  PauloFlixMoviesStatus get status => _status;
  List<PauloFlixMovie> get contents => _filteredContents;
  String? get errorMessage => _errorMessage;
  String get syncProgress => _syncProgress;
  bool get isSyncing => _status == PauloFlixMoviesStatus.loading;

  /// Carrega do banco local (sem chamada de rede).
  Future<void> loadContents() async {
    _status = PauloFlixMoviesStatus.loading;
    notifyListeners();
    try {
      _contents = await _repository.getAll();
      _filteredContents = _contents;
      _status = PauloFlixMoviesStatus.loaded;
    } catch (e) {
      _errorMessage = 'Erro ao carregar filmes: $e';
      _status = PauloFlixMoviesStatus.error;
    }
    notifyListeners();
  }

  /// Sincroniza filmes do PauloFlix + enriquece com TMDB.
  Future<bool> syncContent() async {
    _status = PauloFlixMoviesStatus.loading;
    _syncProgress = 'Iniciando sincronização de filmes...';
    notifyListeners();
    try {
      final success = await PauloFlixMoviesService.syncContent(
        repository: _repository,
        onProgress: (msg) {
          _syncProgress = msg;
          notifyListeners();
        },
        onError: (err) {
          _errorMessage = err;
          notifyListeners();
        },
        // Fase 4 (NFO enrichment) — se o enricher foi injetado via
        // `withServices`, ele é tentado **antes** do TMDB. Se o
        // servidor PauloFlix tem `movie.nfo` na pasta do filme, o
        // `PauloFlixMovie` é construído a partir do NFO. Quando
        // `null` (legacy/tests), comportamento idêntico ao
        // pré-Fase 4: só TMDB.
        enricher: _nfoEnricher,
      );
      if (success) {
        await loadContents();
      } else {
        _status = PauloFlixMoviesStatus.error;
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = 'Erro na sincronização de filmes: $e';
      _status = PauloFlixMoviesStatus.error;
      notifyListeners();
      return false;
    }
  }

  void search(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      final q = query.toLowerCase().trim();
      if (q.isEmpty) {
        _filteredContents = _contents;
      } else {
        _filteredContents = _contents.where((c) {
          return c.displayName.toLowerCase().contains(q) ||
              c.genres.any((g) => g.toLowerCase().contains(q));
        }).toList();
      }
      notifyListeners();
    });
  }

  /// Busca no banco (Drift) por `displayName` (LIKE + ESCAPE).
  ///
  /// **Quando usar**: telas de busca dedicadas (ex:
  /// [PauloFlixMoviesSearchScreen]) que NÃO querem carregar a
  /// lista inteira do provider em memória. Query vazia retorna
  /// lista vazia (não chama SQL).
  ///
  /// **Vantagens sobre o [search] legado (in-memory)**:
  /// - Zero alocação da lista completa do provider.
  /// - Memória constante: só os resultados da query ficam em RAM.
  /// - Funciona bem com milhares de itens (SQLite local é rápido
  ///   para `LIKE` em 10k+ linhas).
  ///
  /// O `search` legado é mantido para outros usos.
  Future<List<PauloFlixMovie>> searchByName(String query) async {
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
  // Métodos puros de agrupamento/ordenação (testáveis diretamente)
  //
  // São `static` para permitir testes sem mockar ChangeNotifier. Mesma
  // estratégia do `applyFilter` da `PauloFlixSearchScreen`. A UI chama
  // esses métodos em `initState`/`didChangeDependencies` (snapshot local)
  // para derivar as seções da home.
  // ───────────────────────────────────────────────────────────────────────

  /// Escolhe o filme/coleção para o hero banner.
  ///
  /// Critério de ranking (em ordem):
  /// 1. Maior [PauloFlixMovie.score] (filmes sem score vão pro final).
  /// 2. Desempate: ano mais recente ([PauloFlixMovie.year]).
  /// 3. Desempate final: maior [PauloFlixMovie.availableMovieCount] —
  ///    preferência por coleções cheias.
  ///
  /// Retorna `null` se [movies] estiver vazia.
  static PauloFlixMovie? pickFeaturedMovie(List<PauloFlixMovie> movies) {
    if (movies.isEmpty) return null;
    final sorted = [...movies]
      ..sort((a, b) {
        final scoreCmp = (b.score ?? 0).compareTo(a.score ?? 0);
        if (scoreCmp != 0) return scoreCmp;
        final yearCmp = (b.year ?? 0).compareTo(a.year ?? 0);
        if (yearCmp != 0) return yearCmp;
        return b.availableMovieCount.compareTo(a.availableMovieCount);
      });
    return sorted.first;
  }

  /// Agrupa filmes pelos [maxGenres] gêneros com mais filmes.
  ///
  /// Para cada gênero top, retorna até [perGenre] filmes ranqueados por
  /// score descendente. Filmes sem score vão pro final do grupo.
  ///
  /// Gêneros com menos de [minPerGenre] filmes NÃO aparecem no map
  /// (heurística do caller para evitar carrosséis de 1 filme).
  static Map<String, List<PauloFlixMovie>> groupByTopGenres(
    List<PauloFlixMovie> movies, {
    int maxGenres = 4,
    int perGenre = 12,
    int minPerGenre = 3,
  }) {
    if (movies.isEmpty) return const {};

    // 1. Conta filmes por gênero.
    final genreCount = <String, int>{};
    for (final m in movies) {
      for (final g in m.genres) {
        if (g.isEmpty) continue;
        genreCount[g] = (genreCount[g] ?? 0) + 1;
      }
    }

    // 2. Top N gêneros por contagem.
    final topGenres =
        genreCount.entries.where((e) => e.value >= minPerGenre).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final selected = topGenres.take(maxGenres).map((e) => e.key).toList();

    // 3. Para cada gênero top, filtra e ranqueia.
    final result = <String, List<PauloFlixMovie>>{};
    for (final g in selected) {
      final filtered = movies.where((m) => m.genres.contains(g)).toList()
        ..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
      result[g] = filtered.take(perGenre).toList();
    }
    return result;
  }

  /// Retorna o ícone Material apropriado para um gênero de filme.
  ///
  /// Tabela hardcoded — se o gênero não estiver mapeado, usa `movie_outlined`.
  /// Gêneros vêm em inglês do TMDB; mapeamento cobre os 20+ mais comuns.
  static String genreIcon(String genre) {
    const map = {
      'Action': 'flash_on',
      'Adventure': 'explore',
      'Animation': 'animation',
      'Comedy': 'sentiment_very_satisfied',
      'Crime': 'gavel',
      'Documentary': 'article',
      'Drama': 'theater_comedy',
      'Family': 'family_restroom',
      'Fantasy': 'auto_awesome',
      'History': 'history_edu',
      'Horror': 'dark_mode',
      'Music': 'music_note',
      'Mystery': 'search',
      'Romance': 'favorite',
      'Science Fiction': 'rocket_launch',
      'Sci-Fi': 'rocket_launch',
      'TV Movie': 'tv',
      'Thriller': 'psychology',
      'War': 'military_tech',
      'Western': 'landscape',
    };
    return map[genre] ?? 'movie_outlined';
  }

  /// Pagina filmes em ordem alfabética para o grid "Todos os Filmes".
  ///
  /// Retorna um [PaginationResult] com:
  /// - [PaginationResult.pages]: lista de páginas (cada uma com até [perPage] filmes).
  /// - [PaginationResult.letterToPageIndex]: mapa letra → índice da primeira
  ///   página que contém filmes com essa letra. Usado pelo `LetterIndex`
  ///   para "pular para letra".
  /// - [PaginationResult.availableLetters]: letras (A–Z + "#") que têm ≥1 filme.
  ///
  /// Filmes com displayName iniciando com número/símbolo caem em "#".
  /// Ordenação é case-insensitive.
  static PaginationResult<PauloFlixMovie> paginateByLetter(
    List<PauloFlixMovie> movies, {
    int perPage = 24,
  }) {
    if (movies.isEmpty) {
      return const PaginationResult<PauloFlixMovie>(
        pages: [],
        letterToPageIndex: {},
        availableLetters: [],
      );
    }

    // 1. Ordena alfabeticamente, agrupando "#" no fim.
    //    Para garantir que "#" venha depois de "Z", usamos uma sentinela
    //    (caractere high-value) ao comparar: '#' (0x23) viria antes de 'A'
    //    (0x41) na comparação default — substituímos por '~' (0x7E) que
    //    está depois de todas as letras maiúsculas.
    final sorted = [...movies]
      ..sort((a, b) {
        final aKey = _sortKey(a.displayName);
        final bKey = _sortKey(b.displayName);
        final cmp = aKey.compareTo(bKey);
        if (cmp != 0) return cmp;
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      });

    // 2. Pagina.
    final pages = <List<PauloFlixMovie>>[];
    for (var i = 0; i < sorted.length; i += perPage) {
      final end = i + perPage > sorted.length ? sorted.length : i + perPage;
      pages.add(sorted.sublist(i, end));
    }

    // 3. Mapeia letra → primeira página onde aparece. Itera por TODOS
    //    os filmes de cada página (não só o primeiro) para capturar letras
    //    que aparecem no meio de uma página.
    final letterToPageIndex = <String, int>{};
    final availableLetters = <String>[];
    for (var i = 0; i < pages.length; i++) {
      for (final m in pages[i]) {
        final letter = _normalizeFirstChar(m.displayName);
        if (!letterToPageIndex.containsKey(letter)) {
          letterToPageIndex[letter] = i;
          // availableLetters em ordem alfabética: a primeira vez que
          // aparece, registramos. Como já passamos por todas as páginas
          // anteriores, isso naturalmente fica em ordem alfabética.
          availableLetters.add(letter);
        }
      }
    }
    // availableLetters deve estar em ordem alfabética para o _LetterIndex.
    // Sort customizado: '#' sempre no fim, letras A–Z na frente (ordem ASCII).
    availableLetters.sort((a, b) {
      if (a == '#') return 1; // '#' sempre depois
      if (b == '#') return -1;
      return a.compareTo(b);
    });

    return PaginationResult<PauloFlixMovie>(
      pages: pages,
      letterToPageIndex: letterToPageIndex,
      availableLetters: availableLetters,
    );
  }

  /// Helper privado: normaliza o primeiro caractere de [name].
  /// Letras A–Z retornam a si próprias; qualquer outra coisa vira "#".
  static String _normalizeFirstChar(String name) {
    if (name.isEmpty) return '#';
    final first = name[0].toUpperCase();
    final isLetter = RegExp(r'^[A-Z]$').hasMatch(first);
    return isLetter ? first : '#';
  }

  /// Helper privado: retorna a chave de ordenação. "#" vira "~" (0x7E) para
  /// que seja maior que qualquer letra A–Z (0x41–0x5A) na comparação default.
  static String _sortKey(String name) {
    final first = _normalizeFirstChar(name);
    return first == '#' ? '~' : first;
  }

  void clearSearch() {
    _filteredContents = _contents;
    notifyListeners();
  }
}

class _NullPauloFlixMoviesRepository implements PauloFlixMoviesRepository {
  @override
  Future<List<PauloFlixMovie>> getAll() async => [];
  @override
  Future<List<PauloFlixMovie>> searchByName(String query) async => [];
  @override
  Future<PauloFlixMovie?> getByFolderName(String folderName) async => null;
  @override
  Future<PauloFlixMovie?> getByTmdbId(int tmdbId) async => null;
  @override
  Future<void> saveContent(PauloFlixMovie content) async {}
  @override
  Future<void> saveBatch(List<PauloFlixMovie> contents) async {}
  @override
  Future<void> markAsUnavailable(String folderName) async {}
  @override
  Future<Map<String, int>> getStats() async => {
    'total': 0,
    'available': 0,
    'withMetadata': 0,
    'collections': 0,
  };
  @override
  Stream<List<PauloFlixMovie>> watch() => const Stream.empty();
}
