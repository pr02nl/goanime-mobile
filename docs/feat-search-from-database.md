# Feature: Busca no banco (Drift) com debounce + tela vazia no load

## Visão geral

Hoje as telas `PauloFlixSearchScreen` e `PauloFlixMoviesSearchScreen`
carregam **todos** os animes/filmes do provider no `initState` e
filtram in-memory (anti-pattern já documentado de "snapshot local
gigante"). Com o crescimento do banco (milhares de itens em breve),
isso fica inviável:

- **Memória**: O(n) bytes de `PauloFlixContent`/`PauloFlixMovie` em
  RAM enquanto a tela está aberta, sem necessidade.
- **Tempo de load**: Atraso entre abrir a tela e mostrar o estado
  "pronto para buscar" — atualmente precisa popular o snapshot antes
  do primeiro frame útil.
- **Escala**: Hoje o filtro é O(n) por keystroke. Com 10k itens,
  150ms de debounce × 6 caracteres = 900ms de CPU só pra filtrar.

**Objetivo**: padrão YouTube/Netflix — tela inicia **vazia**,
query → debounce → query SQL no banco → popula grid. Zero carga
inicial.

## Decisões validadas com o usuário

1. **Telas de busca estão fora do ShellRoute** (ver `app_router.dart`
   linhas 81-90) — então o `FocusScope` persistente do shell
   `MainNavigationScreen` **não está ativo** quando você está nelas.
   Logo, `autofocus: true` no TextField é **seguro** nessas telas
   (anti-pattern #19 do skill `flutter-reactivity-gotchas` não se
   aplica aqui). Vou **re-adicionar** `autofocus: true` no TextField
   e remover o `_searchFocusNode.requestFocus()` no post-frame
   callback.

2. **Tela inicia vazia**. Sem spinner de "carregando" no load
   (snapshot é instantâneo agora). Spinner só durante a busca no
   banco (entre keystroke e resultado). Empty state distinto:
   - Query vazia + sem busca executada → "Digite para buscar"
   - Query vazia + busca executada → nada (lista já está vazia)
   - Query não-vazia + 0 resultados → "Nenhum resultado para X"

3. **Query no banco via `repository.searchByName(query)`** (já
   existe no contrato dos 2 repositories e tem impl Drift com
   `LIKE` + `ESCAPE`). O método SQL **já está implementado e
   testado** — só não estava sendo chamado. A mudança é wirear
   o repository nas search screens.

4. **`applyFilter` estático (função pura testável) vira legado**.
   O filtro era em memória porque o snapshot era local. Com
   query no banco, o filtro sai do app e vai pro SQL. Vou
   **remover** o `applyFilter` das 2 search screens e os testes
   que dependem dele (vou checar quais são).

5. **`PauloFlixProvider.search(query)` e `PauloFlixMoviesProvider.search(query)`**
   — métodos do provider que filtram in-memory — **continuam
   existindo** (não vou mexer neles). Eles são usados em outros
   lugares (ex: `PauloFlixSeeAllScreen` se usar). Foco da mudança
   é só nas 2 search screens, que vão consultar o repository
   direto via `Provider.of(repository)` ou via construtor
   injetado.

   **Detalhe**: as search screens hoje obtêm o provider via
   `context.read<PauloFlixProvider>()` para acessar `contents`.
   O repository é injetado no provider. Para a busca, posso:
   - **(A)** Adicionar `searchByName(query)` no provider que
     delega para o repository → mantém a abstração "UI fala com
     provider, provider fala com repository"
   - **(B)** Injetar o repository diretamente nas search screens
     via construtor (mais limpo mas quebra o pattern atual)

   **Decisão**: (A) — adiciona `searchByName(String query)` em
   cada provider (mesma assinatura que o `search(query)` atual,
   mas assíncrono + delega ao repository). Mantém o
   `search(query)` legado (in-memory) intacto para outros usos.

## Estrutura de arquivos (mudanças)

| Arquivo | Mudança |
|---------|---------|
| `lib/ui/pauloflix/view_models/pauloflix_provider.dart` | Adicionar `Future<List<PauloFlixContent>> searchByName(String query)` que delega ao `_repository.searchByName`. Manter `search(query)` in-memory. |
| `lib/ui/pauloflix_movies/view_models/pauloflix_movies_provider.dart` | Idem com `PauloFlixMovie`. |
| `lib/ui/pauloflix/widgets/pauloflix_search_screen.dart` | **Reescrever** para: tela vazia no load, query no banco via provider, `autofocus: true` no TextField, remover `applyFilter` estático, remover snapshot local `_allContents`. |
| `lib/ui/pauloflix_movies/widgets/pauloflix_movies_search_screen.dart` | Idem. |
| `test/ui/pauloflix/widgets/pauloflix_search_screen_test.dart` | Ajustar testes para o novo comportamento (inicia vazio, mock do `searchByName`). |
| `test/ui/pauloflix_movies/widgets/pauloflix_movies_search_screen_test.dart` | Idem. |

## Algoritmos críticos

### Provider: `searchByName` assíncrono delegando ao repository

```dart
/// Busca no banco (Drift) por `displayName` (LIKE + ESCAPE).
/// Retorna lista vazia se query for vazia (não chama SQL).
///
/// Vantagens sobre o [search] legado:
/// - Zero alocação: não carrega lista inteira do provider.
/// - O(log n) no banco com índice, vs O(n) in-memory.
/// - Memória constante: só os resultados da query ficam em RAM.
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
```

### Search screen: tela vazia no load + query no banco

```dart
class _PauloFlixSearchScreenState extends State<PauloFlixSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(debugLabel: '...');
  final FocusNode _firstCardFocusNode = FocusNode(debugLabel: '...');

  // Tela inicia vazia — sem snapshot, sem provider.read.
  List<PauloFlixContent> _results = const [];
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isTV = false;

  Timer? _debounce;
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    // Detecta TV no primeiro frame (sem tocar provider/repo).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final screenWidth = ...;
      final isTvBuild = await TVDetector.isTV;
      if (!mounted) return;
      setState(() {
        _isTV = isTvBuild || screenWidth >= Responsive.tabletMaxWidth;
      });
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _firstCardFocusNode.dispose();
    super.dispose();
  }

  // Sem `WidgetsBinding.addPostFrameCallback` para foco —
  // `autofocus: true` no TextField cuida disso (essa tela está
  // FORA do ShellRoute, então o FocusScope persistente do shell
  // não está presente — sem risco do anti-pattern #19).

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      _debounce?.cancel();
      setState(() {
        _results = const [];
        _searchQuery = '';
        _isSearching = false;
      });
      return;
    }
    _debounce?.cancel();
    _isSearching = true;
    _debounce = Timer(_debounceDuration, () => _performSearch(query));
  }

  Future<void> _performSearch(String query) async {
    final provider = context.read<PauloFlixProvider>();
    final results = await provider.searchByName(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searchQuery = query.toLowerCase().trim();
      _isSearching = false;
    });
  }

  // ... build igual mas usa _results em vez de _filteredContents
  // ... e considera _isSearching no empty state
}
```

### Empty states distintos

| Estado | Condição | Mostra |
|--------|----------|--------|
| **Idle** (sem query) | `_searchQuery.isEmpty && !_isSearching` | "Digite para buscar animes" + ícone de lupa |
| **Loading** | `_isSearching` | `CircularProgressIndicator` centralizado |
| **Empty result** | `!_isSearching && _searchQuery.isNotEmpty && _results.isEmpty` | "Nenhum resultado para X" + ícone search_off |
| **Results** | `_results.isNotEmpty` | `SliverGrid` com cards |

## Casos a tratar

### 1. Foco inicial (autofocus: true)

`autofocus: true` no `TVSafeTextField` é seguro aqui (tela fora do
ShellRoute). Remove o `_searchFocusNode.requestFocus()` no
post-frame callback — autofocus declarativo é mais simples e
funciona direto no build.

### 2. Cancelar busca anterior

Se o usuário digita "na" e antes do debounce digita "nar", a busca
"na" não deve rodar (o debounce já cancela, mas se a query
anterior já tinha sido disparada e está no `await provider.searchByName`,
o resultado pode voltar depois da "nar"). Solução: guardar
`int _searchGeneration` que incrementa a cada keystroke, e
no `setState` da resposta checar se ainda é a geração atual:

```dart
int _searchGeneration = 0;

Future<void> _performSearch(String query) async {
  final myGen = ++_searchGeneration;
  final provider = context.read<PauloFlixProvider>();
  final results = await provider.searchByName(query);
  if (!mounted) return;
  if (myGen != _searchGeneration) return; // busca mais nova já foi disparada
  setState(() {
    _results = results;
    _searchQuery = query.toLowerCase().trim();
    _isSearching = false;
  });
}
```

### 3. Erro de rede/banco

`searchByName` retorna `[]` em caso de exception (já documentado).
Mostrar empty state "Nenhum resultado" pode confundir. Solução:
manter `_errorMessage` opcional no state e mostrar mensagem
distinta.

### 4. Testes

- `test/ui/pauloflix/widgets/pauloflix_search_screen_test.dart`
  testa `applyFilter` puro (anti-pattern #20) — esses testes
  deixam de fazer sentido. Vou checar quais existem e ajustar:
  - Se o teste chama `PauloFlixSearchScreen.applyFilter(items, query)`:
    **remover** (método não existe mais).
  - Se o teste faz `pumpWidget` da tela com lista: **mudar** para
    mockar o `PauloFlixProvider` e usar `searchByName` mockado.
  - Se o teste só verifica mount sem crashes: **manter** (vai
    funcionar com lista vazia).

## Ordem de implementação

1. **Patch 1**: adicionar `searchByName` em `PauloFlixProvider` +
   `PauloFlixMoviesProvider` (delega ao repository).
2. **Patch 2**: reescrever `PauloFlixSearchScreen` (tela vazia +
   query no banco + autofocus: true).
3. **Patch 3**: reescrever `PauloFlixMoviesSearchScreen` (mesmo).
4. **Patch 4**: ajustar testes dos 2 search screens.
5. **Validação final**: `flutter analyze` + `dart fix --apply` +
   `flutter test`.

## Verificação

- [ ] `flutter analyze` → 0 issues
- [ ] `dart fix --apply` → nada para arrumar
- [ ] `flutter test` → todos passando
- [ ] Repro manual:
  - Abrir busca de animes → tela vazia, TextField com foco, teclado
    virtual aberto
  - Digitar "na" → após 300ms, lista aparece com resultados
  - Limpar campo → tela volta ao estado idle
  - Digitar texto sem match → "Nenhum resultado para X"
  - Digitar rápido (cancelar anterior) → só o último resultado
    aparece (geração)
  - Repetir para filmes

## Riscos & mitigações

- **Risco 1**: `LIKE '%query%'` com `LOWER()` não usa índice simples.
  Para 10k+ itens com query genérica ("a", "e"), pode ser O(n) full
  scan. **Mitigação**: o banco é local (SQLite), scan em 10k linhas
  é < 50ms. Se virar gargalo, **FTS5** no Drift é o próximo passo
  (cria `CREATE VIRTUAL TABLE ... USING fts5(display_name)` + sync).
  Vou deixar um TODO no código se isso virar realidade.
- **Risco 2**: testes existentes do `applyFilter` estático quebram.
  **Mitigação**: ajustar/remover no Patch 4.
- **Risco 3**: UX pior se o usuário espera ver "resultados
  recentes" / "populares" antes de digitar. **Mitigação**: o
  empty state "Digite para buscar animes" deixa claro que precisa
  digitar. Se quiser ver "Top 10 animes PauloFlix" como
  sugestão, é uma feature separada (depois).
- **Risco 4**: chamadas rápidas ao banco em digitação rápida
  (mesmo com debounce 300ms). **Mitigação**: 300ms é
  conservador; com geração + debounce + cancelamento da busca
  anterior, no máximo 1 query roda por vez por usuário.

## Decisões abertas para o usuário

- **Debounce 300ms** (estava 150ms antes). Justificativa: query
  SQL > query in-memory, vale esperar um pouco mais. Aceitável?
- **Empty state "Digite para buscar"** vs manter uma lista
  inicial de "Top 10" / "Mais recentes" para dar algo visual
  imediato. Recomendo a primeira (mais simples, YouTube-like).
  Se preferir a segunda, é uma feature adicional.
