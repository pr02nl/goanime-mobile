# Navegação estilo YouTube TV — `MainNavigationScreen`

> Documentação recarregável entre sessões. Implementação v2 (2026-06-21),
> corrigida após teste real do usuário na TV.
> Plano executável: `.hermes/plans/2026-06-21_youtube-tv-navigation-v2.md`.

## Comportamento (confirmado na TV real)

| Ação | Resultado |
|---|---|
| Load inicial | Sidebar **colapsada** (72px) + foco no conteúdo |
| ← no meio do conteúdo | Move entre itens (não abre sidebar) |
| ← no item mais à esquerda do conteúdo | Sidebar **expande** + foca item da rota ativa |
| ↑↓ na sidebar | **Seleciona** o conteúdo e atualiza o lado direito (foco = ativação). Sidebar permanece expandida |
| → na sidebar | Sidebar **colapsa** + foco volta ao **último item do conteúdo** |
| Enter/Select/click em item | Fecha sidebar + foco no conteúdo (rota já selecionada pelo foco) |
| Back (sidebar fechada) | **Abre+expande** sidebar imediatamente, foca item da rota ativa |
| Back (sidebar aberta) | **Fecha** sidebar + foco volta ao último item do conteúdo |
| Hover/foco em item colapsado | Tooltip com o label |

## Decisão chave: expand/collapse controlado pelo shell

v1 usava listener do `FocusScopeNode` da sidebar para expandir/colapsar.
**Problema**: quando ↑↓ navega (ponto 3), `context.go` rebuilda a nova tela e
seu `autofocus` rouba o foco da sidebar → listener colapsa a sidebar
indevidamente durante a navegação.

**v2**: o shell mantém `bool _sidebarOpen` e passa `expanded: _sidebarOpen` à
sidebar. Expand/collapse é determinístico, independente de flutuações de foco
transitórias. A sidebar só colapsa quando o shell decide (→, Back, Select).

## Arquitetura

### `Sidebar` (`side_bar.dart`)

- **Props**: `location`, `expanded` (do shell), `onClose` (shell fecha).
- **`SidebarState`** (público via `GlobalKey`):
  - `focusActiveItem()` — foca o item da rota ativa (chamado pelo shell ao abrir).
  - `containsNode(FocusNode)` — true se o nó está dentro do escopo da sidebar
    (usado pelo `_SidebarEdgeAction` para distinguir conteúdo vs sidebar).
  - `hasFocus` getter — `_scopeNode.hasFocus`.
- **`_SidebarTraversalPolicy`** — ↑↓ usa `next()`/`previous()` (ordered
  traversal) para ignorar gaps de 4px entre itens (rect-based falha com gaps).
  ← → é interceptado pelo shell antes de chegar aqui.
- **`_SidebarItem`**:
  - `onFocus` → `_onItemFocus(index)`: se `!isSelected(location)` →
    `context.go(target)` + post-frame re-foca o item (contrapor autofocus steal).
  - `onSelect` → `_onItemSelect(index)`: se `!isSelected(location)` →
    `context.go(target)` + `widget.onClose()`.
- **Todos os itens usam `context.go`** (não `push`) — sem back-stack entre
  seções (Back controla sidebar, per YouTube TV).

### `_MainNavigationScreenState` (`main_navigation_screen.dart`)

- **`_sidebarOpen`** (bool) — controle de expand/collapse.
- **`_contentScopeNode`** (FocusScopeNode) — envolve o conteúdo via `FocusScope`.
  Listener `_onContentFocusChange` grava `_lastContentFocusNode` quando o
  conteúdo tem foco.
- **`_restoreContentFocus()`** — `_lastContentFocusNode` (se válido) →
  `_contentScopeNode.focusedChild` → `unfocus()` (fallback).
- **`_openSidebar()`** — `setState(_sidebarOpen=true)` + post-frame
  `focusActiveItem()`.
- **`_closeSidebar()`** — `setState(_sidebarOpen=false)` + post-frame
  `_restoreContentFocus()`.
- **Back button** (`_onHardwareKey` + `_onBackButton`):
  - `HardwareKeyboard.instance.addHandler` intercepta `goBack` (KeyDownEvent).
  - Só trata se `isWide` (via `platformDispatcher.views.first`) E
    `_shellHasFocus()` (sidebar ou conteúdo com foco — não intercepta em
    telas de detalhe pushed fora do shell).
  - `return true` consome o key event → suprime o system pop.
  - `_onBackButton()` (debounce 300ms): se `_sidebarOpen` → `_closeSidebar`;
    senão → `_openSidebar`.
  - `PopScope(canPop: isWide ? false : location=='/')` — safety net.
- **`_isAtLeftEdge(node)`** (rect-based, síncrono): o nó é o mais à esquerda
  na sua linha (mesma banda vertical) dentro do conteúdo? Filtra nós da
  sidebar via `containsNode`. Não depende de `requestFocus` (assíncrono).
- **`_SidebarEdgeAction`** (4 callbacks):
  - ← na sidebar → no-op.
  - ← no conteúdo no edge → `onLeftEdge` (`_openSidebar`).
  - ← no conteúdo no meio → `DirectionalFocusAction` default (move entre cards).
  - → na sidebar → `onRightEdgeFromSidebar` (`_closeSidebar`).
  - → no conteúdo → default.
  - ↑↓ → default.

## Bugs corrigidos (v1 → v2)

| Bug v1 | Causa | Correção v2 |
|---|---|---|
| ← sempre abre sidebar | `primaryFocus == before` após `requestFocus` (assíncrono) → sempre true | Detecção rect-based `_isAtLeftEdge` (síncrono) |
| → na sidebar não fecha | `FocusTraversalGroup` não deixa → escapar | `_SidebarEdgeAction` intercepta → na sidebar → `_closeSidebar` |
| ↑↓ não seleciona | v1 removeu `onFocus: onTap` (assunção errada) | Re-adicionar `onFocus` → `context.go` + re-focus pós-frame |
| Back fecha app | `PopScope` não bloqueia no ShellRoute | `HardwareKeyboard` consome `goBack` + `PopScope(canPop:false)` safety net |
| Sidebar colapsa durante ↑↓ (autofocus steal) | Listener de foco do escopo colapsa on focus loss | Expand/collapse controlado pelo shell (`_sidebarOpen`), não por listener |

## Verificação

```bash
flutter analyze          # 0 issues
dart fix --apply         # nothing to fix
flutter analyze          # 0 issues
flutter test             # All tests passed (70)
```

## Riscos & mitigações

| Risco | Mitigação |
|---|---|
| `HardwareKeyboard` não suprime system pop em todos os devices | `PopScope(canPop:false)` como safety net; se persistir, adicionar `WillPopScope` |
| Back no load (antes do autofocus) → não intercepta → exit | Edge case breve; após autofocus, `_shellHasFocus()` é true |
| `_onItemFocus` chama `context.go` de dentro de focus listener | `context.go` é deferred (não rebuild síncrono) — seguro |
| Content sem autofocus → `_restoreContentFocus` cai em `unfocus()` | Usuário pressiona arrow → d-pad foca primeiro focusable do conteúdo |
| `FocusableWidget` mapeia `goBack` → `DismissIntent` | `HardwareKeyboard` handler roda antes e consome Back → `DismissIntent` não dispara |

## Itens fora de escopo

- Breakpoint `>= 600px` (`Responsive.phoneMaxWidth`).
- Lista de itens da sidebar.
- Drawer mobile (`_DrawerMenu`) — não mudou.
- `FocusableWidget`, `KeyActivable`, carrosséis (`_ClampedTraversalPolicy`).
- Telas de conteúdo — não refatoradas (apenas tracking de foco via `_contentScopeNode`).
- Comportamento Back no mobile (legado `canPop: location == '/'`).

## Referências

- Skill `flutter-development` → "Custom Focus Traversal Policies".
- Skill `flutter-reactivity-gotchas` → #14 (d-pad), #16 (TextField foco).
- `references/focus-traversal-policy.md` — `_ClampedTraversalPolicy`,
  `_SidebarTraversalPolicy`, `_SidebarEdgeAction`.
