# Fix: Assertion `Focused child does not have the same idea of its enclosing scope`

## Visão geral

Bug intermitente em wide layout (TV/desktop/tablet ≥ 600px) ao abrir
qualquer rota filha do shell `MainNavigationScreen` que tenha um widget
descendente com `autofocus: true` declarado, **enquanto uma ModalRoute está
sendo aberta ou fechada por cima** (sheet, dialog, drawer).

A stack trace completa é:

```
════════ Exception caught by foundation library ════════════════════════════════
The following assertion was thrown while dispatching notifications for FocusScopeNode:
null: Focused child does not have the same idea of its enclosing scope (null) as the scope does.
'package:flutter/src/widgets/focus_manager.dart':
Failed assertion: line 1397 pos 7: '_focusedChildren.isEmpty || _focusedChildren.last.enclosingScope == this'

When the exception was thrown, this was the stack:
#2      FocusScopeNode.focusedChild (package:flutter/src/widgets/focus_manager.dart:1397:7)
#3      _MainNavigationScreenState._onContentFocusChange (package:goanime/ui/navigation/main_navigation_screen.dart:75:41)
#4      ChangeNotifier.notifyListeners (package:flutter/src/foundation/change_notifier.dart:435:24)
#5      FocusNode._notify (package:flutter/src/widgets/focus_manager.dart:1131:5)
#6      FocusManager.applyFocusChangesIfNeeded (package:flutter/src/widgets/focus_manager.dart:1995:12)
(elided 4 frames from class _AssertionError and dart:async)

The FocusScopeNode sending notification was: FocusScopeNode#59895([IN FOCUS PATH])
    context: FocusScope
    IN FOCUS PATH
    focusedChildren: FocusScopeNode#5bdeb(_ModalScopeState<dynamic> Focus Scope [PRIMARY FOCUS]), FocusScopeNode#f4eab(_ModalScopeState<dynamic> Focus Scope)
```

## Diagnóstico

### Anatomia do bug (anti-pattern #19 do skill `flutter-reactivity-gotchas`)

A recipe para esse bug aparecer tem 3 ingredientes — todos presentes no
GoAnime Mobile:

1. **Shell tem um `FocusScopeNode` persistente** (field de instância do
   `_MainNavigationScreenState`, sobrevive entre navegações):
   ```dart
   // lib/ui/navigation/main_navigation_screen.dart:45
   final FocusScopeNode _contentScopeNode = FocusScopeNode();
   ```
   É usado em `_buildWideLayout` (linha 236) para tracking do último
   item focado no conteúdo, com listener adicionado no `initState`:
   ```dart
   // lib/ui/navigation/main_navigation_screen.dart:57, 73-80
   _contentScopeNode.addListener(_onContentFocusChange);
   void _onContentFocusChange() {
     if (_contentScopeNode.hasFocus) {
       final focused = _contentScopeNode.focusedChild;  // ← linha 75
       ...
     }
   }
   ```

2. **Rota filha usa `autofocus: true` num widget `Focus` declarativo** —
   isto é, o `Focus` widget **não recebe um `FocusNode` próprio**; o
   Flutter cria um `FocusNode` interno efêmero, descartado quando o
   widget sai da árvore. Candidatos no projeto:
   - `lib/ui/core/widgets/netflix_card.dart:67` → `autofocus: widget.autofocus` (parâmetro público, default `false`)
   - `lib/ui/core/widgets/netflix_hero_card.dart:137` → `autofocus: isTV` (botão Play)
   - `lib/ui/core/widgets/netflix_hero_card.dart:216` → `autofocus: widget.autofocus`
   - `lib/ui/pauloflix/widgets/pauloflix_search_screen.dart:236` → `autofocus: true` (TextField da AppBar)
   - `lib/ui/pauloflix_movies/widgets/pauloflix_movies_search_screen.dart:229` → `autofocus: true` (TextField da AppBar)
   - `lib/ui/core/widgets/tv_safe_text_field.dart:200` → `autofocus: widget.autofocus` (parâmetro)

3. **Modal route aberta por cima** (no momento do assertion, o stack de
   `focusedChildren` do `_contentScopeNode` contém 2 `_ModalScopeState`).
   Situações conhecidas que disparam modais:
   - `SourceSelectionScreen` (push sem sheet)
   - Sheet de legendas no player (`VideoPlayerSubtitleSheet`)
   - `EpisodeListScreen` via `Navigator.push` na TV
   - Drawer lateral (mas isso é em mobile, não wide)

A window da race condition: quando a ModalRoute começa a fechar (ou
quando a rota filha está sendo reparented sob o `_contentScopeNode`),
o `FocusNode` interno do widget com `autofocus: true` é disposed no
meio da notificação de focus change. O `_onContentFocusChange` do shell
dispara e tenta ler `_contentScopeNode.focusedChild` — o getter
`focusedChild` em `focus_manager.dart:1397` executa a assertion
`_focusedChildren.last.enclosingScope == this` porque o último nó da
lista tem `enclosingScope == null` (foi disposed).

### Por que o `flutter analyze` não pega

- Nenhum lint cobre "Focus com `autofocus: true` debaixo de um
  `FocusScope(node: ...)` persistente gerenciado por um State"
- O `focusedChild` getter é privado; não há como checar em tempo de
  análise
- A race só acontece com `ModalRoute` por cima + reparenting

## Decisões validadas

1. **Remover `autofocus: true` declarativo de widgets descendentes do
   `_contentScopeNode`** — o shell já gerencia foco via
   `_lastContentFocusNode` + `_restoreContentFocus`. `autofocus`
   declarativo é redundante **e** causa a race.
2. **Defender o listener `_onContentFocusChange` no shell** — checar
   `_contentScopeNode.focusedChild` de forma defensiva (try/catch
   envolvendo o getter — **NÃO**, o getter lança assertion, não
   exception). Alternativa: guardar o último valor válido conhecido
   em vez de ler o getter sob race. **Decisão:** verificar
   `hasFocus` e pular o acesso ao `focusedChild` se algum estado
   interno estiver inválido.
3. **Mover a "força de foco no item X ao abrir" para `addPostFrameCallback`**
   com `FocusNode` próprio mantido como field do State — esse é o
   padrão já documentado em `paginated_letter_grid.dart:20-22` e
   `pauloflix_see_all_screen.dart:19-20`.

## Estrutura de arquivos (mudanças)

| Arquivo | Mudança |
|---------|---------|
| `lib/ui/navigation/main_navigation_screen.dart` | Defender `_onContentFocusChange` e `_restoreContentFocus` contra race (linhas 73-96) |
| `lib/ui/core/widgets/netflix_card.dart` | Remover parâmetro `autofocus` + `Focus(autofocus: ...)` interno; foco vem do shell |
| `lib/ui/core/widgets/netflix_hero_card.dart` | Remover `autofocus: isTV` do botão Play (linha 137) e `autofocus: widget.autofocus` (linha 216); foco vem do shell |
| `lib/ui/core/widgets/tv_safe_text_field.dart` | **Manter** parâmetro `autofocus` (TextField é caso especial — se for removido, o usuário perde a capacidade de digitar ao abrir a tela). Adicionar guard no wrapper para não chamar `autofocus: true` em wide layout. |
| `lib/ui/pauloflix/widgets/pauloflix_search_screen.dart` | Trocar `autofocus: true` (linha 236) por `addPostFrameCallback` no `initState` chamando `_searchFocusNode.requestFocus()` |
| `lib/ui/pauloflix_movies/widgets/pauloflix_movies_search_screen.dart` | Idem (linha 229) |
| Call sites que passam `autofocus: true` para `NetflixCard` / `NetflixHeroCard` | Remover parâmetro (devem passar `false` por default ou omitir) |

### Lista de call sites a verificar

A serem conferidos durante o patch:

- `lib/ui/pauloflix/widgets/pauloflix_see_all_screen.dart:633` — `NetflixCard(...)` sem `autofocus`?
- `lib/ui/pauloflix/widgets/pauloflix_search_screen.dart:372` — idem
- `lib/ui/pauloflix_movies/widgets/_movie_section.dart:46` — idem
- `lib/ui/pauloflix_movies/widgets/_movies_paginated_grid.dart:33` — idem
- `lib/ui/pauloflix_movies/widgets/_movie_hero_banner.dart:32` — `NetflixHeroCard(...)` sem `autofocus`?
- `lib/ui/core/widgets/paginated_letter_grid.dart:238` — idem
- `lib/ui/watchlist/widgets/watchlist_screen.dart:160` — idem
- `lib/ui/home/widgets/home_screen.dart:72` — idem

## Algoritmos críticos

### Defesa do listener (defesa em profundidade)

```dart
void _onContentFocusChange() {
  // O getter `focusedChild` faz assertion
  // `_focusedChildren.last.enclosingScope == this`. Durante reparenting
  // de rota filha + ModalRoute por cima, o `enclosingScope` pode
  // transitóriamente ser `null` enquanto o nó é disposed. Pular o
  // callback nesse caso (evento seguinte restabelece o estado).
  if (!_contentScopeNode.hasFocus) return;
  if (!_contentScopeNode.hasPrimaryFocus &&
      !_contentScopeNode.children.any((n) => n.hasPrimaryFocus)) {
    return;
  }
  final focused = _contentScopeNode.focusedChild;
  if (focused == null) return;
  _lastContentFocusNode = focused;
}
```

### Substituição de `autofocus: true` em search screens

```dart
// Antes (linha 236 de pauloflix_search_screen.dart)
TVSafeTextField(
  controller: _searchController,
  focusNode: _searchFocusNode,
  autofocus: true,             // ❌ causa race com FocusScope do shell
  ...
)

// Depois
TVSafeTextField(
  controller: _searchController,
  focusNode: _searchFocusNode,
  // sem autofocus — initState cuida via post-frame
  ...
)

// initState (já existe, só adicionar o callback)
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted) _searchFocusNode.requestFocus();
});
```

### Substituição de `autofocus: widget.autofocus` em NetflixCard

**Decisão:** remover o parâmetro `autofocus` da API pública. O
NetflixCard **nunca** precisa forçar foco — quem precisa é o shell.
Isso elimina o vetor da race de uma vez.

```dart
// Antes
class NetflixCard extends StatefulWidget {
  final bool autofocus;
  const NetflixCard({super.key, this.autofocus = false, ...});
  ...
}

// Depois
class NetflixCard extends StatefulWidget {
  // Removido: o shell gerencia o foco inicial via
  // _lastContentFocusNode + _restoreContentFocus.
  const NetflixCard({super.key, ...});
  ...
}

// No build:
return Focus(
  // SEM autofocus — shell decide
  onFocusChange: _handleFocus,
  onKeyEvent: ...,
  child: ...,
);
```

## Ordem de implementação

1. **Patch 1**: defender `_onContentFocusChange` e `_restoreContentFocus`
   em `main_navigation_screen.dart` (curto prazo — mata o crash mesmo
   se `autofocus: true` continuar).
2. **Patch 2**: remover parâmetro `autofocus` de `NetflixCard` e do
   `Focus` interno; ajustar todos os call sites (deixar de passar
   `autofocus: ...`).
3. **Patch 3**: remover `autofocus: isTV` do `_HeroActionButton` e
   `autofocus: widget.autofocus` do `NetflixHeroCard`; ajustar call
   sites.
4. **Patch 4**: substituir `autofocus: true` por `addPostFrameCallback`
   em `pauloflix_search_screen.dart` e `pauloflix_movies_search_screen.dart`.
5. **Validação**: `flutter analyze` + `dart fix --apply` + `flutter test`.

## Verificação

- [ ] `flutter analyze` retorna `No issues found!`
- [ ] `dart fix --apply` retorna 0 mudanças
- [ ] `flutter test` passa (suite completa)
- [ ] Repro manual em wide layout:
  - Abrir home → pressionar ↑↓ (sidebar deve expandir/colapsar corretamente)
  - Navegar para `/pauloflix-search` → TextField recebe foco, teclado aparece
  - Abrir source selection → voltar → sem exception no log
  - Abrir subtitle sheet no player → fechar → sem exception no log

## Riscos & mitigações

- **Risco 1**: Remover `autofocus` do `NetflixCard` pode fazer com que
  o **primeiro card do primeiro carrossel da home** não ganhe foco
  ao abrir a tela. **Mitigação**: o `_restoreContentFocus` no shell
  (linha 84-96) já cuida disso se o usuário navegou antes; se for a
  primeira visita, o `primaryFocus` é `null` e o `unfocus()` deixa o
  d-pad livre. Aceitável — usuário aperta ↑↓ para começar.
- **Risco 2**: Remover `autofocus: true` do `TVSafeTextField` em
  search screens pode impedir o usuário de digitar sem clicar
  primeiro. **Mitigação**: usar `addPostFrameCallback` no `initState`
  para forçar foco no `_searchFocusNode` (que é field do State, não
  efêmero).
- **Risco 3**: Defensiva no shell pode mascarar outros bugs. **Mitigação**:
  o listener continua disparando, só pula leituras inválidas. Logs
  podem ser adicionados depois se necessário.
