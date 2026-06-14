# Busca de filmes via ActionBar (PauloFlix Movies)

## Visão geral
A `PauloFlixMoviesHomeScreen` tinha um `TextField` que travava o foco de teclado no desktop/d-pad — só saía dele via `Tab`. Decisão: remover o `TextField` local e delegar a busca para uma **tela dedicada** `PauloFlixMoviesSearchScreen`, acessível via `IconButton.search` no `AppBar` do `MainNavigationScreen` (que já existe para animes).

A `SearchScreen` (animes) e a nova `PauloFlixMoviesSearchScreen` (filmes) ficam separadas para:
- Cada contexto trata seu próprio dataset/provider
- Sem acoplar telas complexas de animes à lógica de filmes
- A linha do `IconButton.search` roteia dinamicamente conforme `_contentType`

## Decisões validadas com o usuário
- Tela **dedicada** (`PauloFlixMoviesSearchScreen`) — Opção C explícita do `clarify`
- Filtro local no estado da tela (NÃO chama `provider.search()` global para evitar que a home mostre resultados filtrados quando voltar)
- Roteamento via `_contentType` no `_openSearch` do `MainNavigationScreen` — o mesmo botão do AppBar serve para ambos

## Estrutura de arquivos

### A criar
- `lib/screens/pauloflix_movies_search_screen.dart`

### A editar
- `lib/screens/main_navigation_screen.dart` — `_openSearch` roteia por `_contentType`
- `lib/screens/pauloflix_movies_home_screen.dart` — remover `TextField`, `_searchQuery`, `_onSearchChanged`, e a `SliverToBoxAdapter` da busca

## Algoritmos críticos

### Snapshot local para busca
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final provider = context.read<PauloFlixMoviesProvider>();
    _allContents = List<PauloFlixMovie>.from(provider.contents);
    _filteredContents = _allContents;
    setState(() {});
  });
}

void _onSearchChanged(String query) {
  setState(() {
    _searchQuery = query.toLowerCase().trim();
    _filteredContents = _searchQuery.isEmpty
        ? _allContents
        : _allContents.where((c) =>
            c.displayName.toLowerCase().contains(_searchQuery) ||
            c.genres.any((g) => g.toLowerCase().contains(_searchQuery))).toList();
  });
}
```

### Roteamento no `_openSearch`
```dart
void _openSearch() {
  Widget target = _contentType == ContentType.movie
      ? const PauloFlixMoviesSearchScreen()
      : const SearchScreen();
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => target),
  );
}
```

### UX de teclado
- `autofocus: true` no `FocusNode` do campo → teclado (ou foco) entra direto
- `Esc` no `HardwareKeyboard` → `Navigator.pop()` (sai da tela)
- `onSubmitted` (Enter) → já é teclado mobile, em TV dispara busca
- `TextField.filled = true` com corner radius igual ao da home (consistência visual)
- Sem chave de busca global, sem bug de focus permanente

## Ordem de implementação
1. Criar `lib/screens/pauloflix_movies_search_screen.dart`
2. Editar `main_navigation_screen.dart` para rotear
3. Editar `pauloflix_movies_home_screen.dart` (remover TextField)
4. `flutter analyze` + `dart fix --apply` + `flutter test`

## Verificação
- `flutter analyze`: 0 issues
- `dart fix --apply`: nothing
- `flutter test`: passa
- Manual no desktop: digitar → lista filtra → Esc volta
- Manual na home: o TextField não está mais lá, banner/contador OK

## Riscos & mitigações
- **Provider compartilhado**: a busca usa snapshot local, não toca no `_filteredContents` do provider. Mitigado: lista snapshot copiada em `initState`.
- **Botão X de limpar no campo**: comportamento idêntico à versão anterior, copia código para consistência.
- **iOS teclado virtual**: `autofocus: true` pode abrir teclado mobile automaticamente. Aceitável para UX esperada.
