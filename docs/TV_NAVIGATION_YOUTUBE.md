# Navegação estilo YouTube TV — `MainNavigationScreen`

> Documentação recarregável entre sessões. Implementado em 2026-06-21.
> Plano executável em `.hermes/plans/2026-06-21_youtube-tv-navigation.md`.

## Visão geral

O shell de navegação (`lib/ui/navigation/main_navigation_screen.dart` +
`lib/ui/navigation/side_bar.dart`) reproduz o comportamento do YouTube TV na
TV/desktop: sidebar colapsada por padrão, expansão por foco, foco ≠ ativar,
foco sempre devolvido ao conteúdo.

## Comportamento (D-pad / teclado)

| Ação | Resultado |
|---|---|
| Load inicial | Sidebar **colapsada** (72px, só ícones) + **foco no conteúdo** |
| ← no conteúdo (edge esquerdo) | Sidebar **expande** (220px) + foca o **item da rota ativa** |
| ↑↓ na sidebar | Move o anel de foco entre itens. **Nada navega** (focar ≠ ativar) |
| → na sidebar | Sidebar **colapsa** + foco **volta ao conteúdo** |
| Enter/Select/click em item | Navega para a rota + sidebar **colapsa** + foco **vai ao conteúdo** |
| Hover/foco em item colapsado | Tooltip com o label |

## Arquitetura de foco

### `Sidebar` (`side_bar.dart`)

- **State público `SidebarState`** (acessível via `GlobalKey<SidebarState>`)
  — permite ao shell chamar `focusActiveItem()`.
- **`FocusScopeNode _scopeNode`** envolve toda a sidebar via
  `FocusScope(node: _scopeNode)`. Um listener em `_scopeNode` detecta
  ganho/perda de foco do grupo:
  - `hasFocus: false → true` (ganhou foco vindo de fora): expande +
    `_focusActiveItem()` redireciona ao item da rota ativa.
  - `hasFocus: true → false` (perdeu foco): colapsa.
- **`List<FocusNode> _itemFocusNodes`** — um por item; passados ao
  `FocusableWidget` de cada `_SidebarItem`. Permite focar o item ativo de
  fora.
- **`_hadFocus`** guarda o estado anterior para detectar transição
  "ganhou vindo de fora" (e evitar loop no redirecionamento).

### `_SidebarItem` (`side_bar.dart`)

- **Sem `onFocus`** — focar (d-pad ↑↓) **não navega**. Só `onSelect`
  (Enter/Select/click) ativa.
- **Sem `autoFocus`** — o foco inicial é do conteúdo, não da sidebar.
- `selected` é só indicador visual da rota ativa (cor primária no
  ícone/label); `focused` é o anel do d-pad. **Independentes**.

### `_SidebarEdgeAction` (`main_navigation_screen.dart`)

- Intercepta `DirectionalFocusIntent` no `_buildWideLayout` via `Actions`.
- ← no conteúdo: chama `DirectionalFocusAction().invoke(intent)` (tenta
  mover o foco). Se `primaryFocus` não mudou (edge esquerdo do conteúdo),
  chama `onLeftEdge` → `_sidebarKey.currentState?.focusActiveItem()`.
- Demais direções (→, ↑, ↓): delega ao `DirectionalFocusAction` default.

### `_MainNavigationScreenState`

- **Sem `_sidebarExpanded` / `_expandSidebar` / `_collapseSidebar`** — a
  expansão é interna da sidebar (por foco do grupo), não state do pai.
- **`GlobalKey<SidebarState> _sidebarKey`** — acessa `focusActiveItem()`.
- `_buildWideLayout` envolve o `Row` em `Actions` com
  `DirectionalFocusIntent: _SidebarEdgeAction(onLeftEdge: ...)`.

## Decisões validadas

1. **Expansão por foco do grupo, não state manual** — a sidebar expande
   quando `_scopeNode.hasFocus` vira true, colapsa quando vira false.
   Remove a necessidade de `_sidebarExpanded` no shell.
2. **`focusActiveItem()` redireciona ao item da rota ativa** — quando a
   sidebar ganha foco vindo de fora (← do conteúdo), o listener
   redireciona ao item `selected`. Evita que o d-pad caia num item
   aleatório (o Flutter faria traversal espacial).
3. **`FocusScope.of(ctx).unfocus()` após selecionar item** — devolve o
   foco ao escopo da rota filha, onde a nova tela pode ter autofocus.
4. **→ na sidebar é natural** — o Flutter move o foco para o conteúdo à
   direita na `Row`; a sidebar colapsa automaticamente ao perder foco.
   Sem handler especial.
5. **`FocusableWidget` recebe `focusNode` do pai** — assim a sidebar
   controla quais nodes focar. O `FocusableWidget` não descarta nodes
   que recebeu (`if (widget.focusNode == null) _focusNode.dispose()`).

## Bugs corrigidos (estado anterior)

| Bug | Causa | Correção |
|---|---|---|
| Focar item navegava sem Enter | `onFocus: onTap` no `_SidebarItem` | Removido `onFocus` |
| Sidebar roubava foco no load | `autoFocus: selected` no `_SidebarItem` | Removido `autoFocus` |
| Sidebar nunca expandia | `_SidebarEdgeAction` definido mas não conectado; `_expandSidebar` nunca chamado | Conectado via `Actions` no `_buildWideLayout` + expansão por foco do grupo |
| Sidebar não colapsava ao perder foco | `onClose` só chamado no `onTap` dos itens | Colapso automático via listener do `_scopeNode` |
| Foco não voltava ao conteúdo após Select | Sem `unfocus` após navegar | `FocusScope.of(ctx).unfocus()` em `_onItemTap` |
| `selected` e `focused` convergiam | `onFocus: onTap` mutava a rota ao focar | Removido `onFocus` — independentes |

## Polimento (Fase 2)

- **Logo no topo** da sidebar (`_buildLogo`) — não-focusable, visual only.
- **Scroll vertical** via `SingleChildScrollView` — suporta mais itens
  sem estourar.

## Itens fora de escopo (não alterados nesta iteração)

- Breakpoint `>= 600px` (`Responsive.phoneMaxWidth`) para layout wide.
- Lista de itens da sidebar (Início, Animes, Filmes, Buscar, Favoritos,
  Downloads, Ajustes).
- Drawer mobile (`_DrawerMenu`).
- `FocusableWidget`, `KeyActivable`.
- Telas de conteúdo (HomeScreen, SearchScreen, etc.) — o foco inicial
  depende do autofocus de cada tela; o shell não força.

## Verificação

```bash
flutter analyze          # 0 issues
dart fix --apply         # nothing to fix
flutter analyze          # 0 issues (re-confirm)
flutter test             # All tests passed (70)
```

**Teste manual (TV/desktop):**

1. Load → sidebar colapsada, foco no conteúdo.
2. ← no conteúdo → sidebar expande, foco no item da rota ativa.
3. ↑↓ na sidebar → move anel de foco, nada navega.
4. → na sidebar → colapsa, foco volta ao conteúdo.
5. Enter em "Buscar" → vai para /search, sidebar colapsa, foco no campo
   de busca ou primeiro card.
6. Hover/foco em item colapsado → tooltip com label.

## Riscos & mitigações

| Risco | Mitigação |
|---|---|
| `unfocus()` não devolve foco ao conteúdo se a nova tela não tem autofocus | Telas de conteúdo devem ter `autofocus` no primeiro elemento (responsabilidade delas, não do shell) |
| Listener do `_scopeNode` causa loop de foco | Guarda `_hadFocus` + `if (!target.hasFocus)` antes de `requestFocus` |
| ← no meio de um carrossel deveria mover entre cards, não ir à sidebar | `_SidebarEdgeAction` só chama `onLeftEdge` quando o foco **não se move** (edge); ← no meio move entre cards normalmente |
| `FocusScopeNode` não é descartado | `dispose()` remove listener e descarta `_scopeNode` + `_itemFocusNodes` |

## Referências

- Skill `flutter-development` → "Custom Focus Traversal Policies" e
  "NavigationRail + Drawer as AppBar Replacement".
- Skill `flutter-reactivity-gotchas` → seção #14 (d-pad), #16 (TextField
  foco), #17 (TextButton invisível ao d-pad).
- `references/focus-traversal-policy.md` (skill flutter-development) —
  `_ClampedTraversalPolicy`, `_SidebarTraversalPolicy`, `_LeftEdgeMenuAction`.
