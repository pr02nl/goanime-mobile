# Plano v2: Navegação estilo YouTube TV — comportamento corrigido

> Revisão após teste real do usuário na TV. O plano v1 assumiu "focar ≠ ativar"
> incorretamente. O YouTube TV ativa no foco (↑↓). Ver correções abaixo.

## Comportamento alvo (confirmado pelo usuário na TV real)

1. **← no conteúdo** abre a sidebar **APENAS** quando o foco está no item
   selecionável mais à esquerda do conteúdo (edge). ← no meio de um carrossel
   move entre cards (não abre sidebar).
2. **→ na sidebar** (com foco) fecha a sidebar e devolve o foco ao **último
   item selecionado no conteúdo**. (Hoje só fecha via Select em outro item.)
3. **↑↓ na sidebar** seleciona o conteúdo e atualiza o lado direito
   imediatamente — **foco = ativação**. (Hoje só ativa com Select.)
4. **Botão Back** do d-pad: se sidebar fechada → abre+expande imediatamente
   (independente do foco atual); se sidebar aberta → fecha + devolve foco
   ao último item do conteúdo. (Hoje Back fecha o app.)

## Bugs a corrigir do estado v1

| Bug v1 | Causa | Correção v2 |
|---|---|---|
| ← sempre abre sidebar (ponto 1) | `_SidebarEdgeAction` usa `primaryFocus == before` após `requestFocus` — mas `requestFocus` é assíncrono, então `primaryFocus` não mudou síncrono → `onLeftEdge` sempre dispara | Detecção rect-based: só abre sidebar se o nó for o **mais à esquerda na sua linha** (mesma banda vertical), filtrando nós da sidebar |
| → na sidebar não fecha (ponto 2) | `FocusTraversalGroup` da sidebar não deixa → escapar para o conteúdo (sem alvo à direita dentro do grupo) | `_SidebarEdgeAction` intercepta → na sidebar → `_closeSidebar()` + `_restoreContentFocus()` |
| ↑↓ não seleciona (ponto 3) | v1 removeu `onFocus: onTap` ("focar ≠ ativar" — incorreto) | Re-adicionar `onFocus` → navegar via `context.go` + **re-focar o item pós-frame** para contrapor autofocus steal da nova tela |
| Back fecha app (ponto 4) | `PopScope(canPop: location=='/')` não bloqueia no ShellRoute | `HardwareKeyboard` intercepta `goBack` (consome) + `PopScope(canPop:false)` como safety net |

## Arquitetura v2

### Controle de expand/collapse: shell, não sidebar

v1 usava listener do `FocusScopeNode` da sidebar para expandir/colapsar.
Problema: autofocus steal da nova tela (ponto 3) causa perda de foco →
colapso indesejado durante ↑↓.

v2: o shell mantém `bool _sidebarOpen` e passa `expanded: _sidebarOpen` à
sidebar. Expand/collapse é determinístico, independente de flutuações de
foco transitórias.

### Tracking do último foco no conteúdo

- `FocusScopeNode _contentScopeNode` envolve o conteúdo (`FocusScope`).
- Listener `_onContentFocusChange`: quando `_contentScopeNode.hasFocus` é
  true, grava `_lastContentFocusNode = _contentScopeNode.focusedChild`.
- `_restoreContentFocus()`: se `_lastContentFocusNode` válido (context != null)
  → `requestFocus()`; senão `_contentScopeNode.focusedChild?.requestFocus()`;
  senão `unfocus()` (d-pad do conteúdo foca no primeiro arrow).

### Ponto 3 — foco = ativação, sem colapso

`_SidebarItem`:
- `onFocus: () => _onItemFocus(index)` — ↑↓ move foco → navega.
- `onSelect: () => _onItemSelect(index)` — Enter/Select/click → fecha sidebar.

`_onItemFocus(index)`:
1. Se `!isSelected(location)` → `context.go(target)` (navega só se mudar rota).
2. `addPostFrameCallback` → se o item perdeu foco (autofocus steal) →
   `_itemFocusNodes[index].requestFocus()` (re-foca, sidebar continua expandida
   via `_sidebarOpen=true`).

`_onItemSelect(index)`:
1. Se `!isSelected(location)` → `context.go(target)` (caso clique sem foco prévio).
2. `widget.onClose()` → shell `_closeSidebar()` + `_restoreContentFocus()`.

Todos os itens usam `context.go` (não `push`) — sem back-stack entre seções
(Back controla sidebar, per YouTube TV).

### Ponto 1 — ← só no edge esquerdo

`_SidebarEdgeAction.invoke(left)`:
- Se `isInSidebar(node)` → return (sidebar já aberta, ← não faz nada).
- Se `_isAtLeftEdge(node)` → `onLeftEdge()` (`_openSidebar`).
- Senão → `DirectionalFocusAction().invoke(intent)` (move ← dentro do conteúdo).

`_isAtLeftEdge(node)` (rect-based, síncrono — não depende de requestFocus async):
1. `scope = node.nearestScope` → `scope.traversalDescendants` (nós do mesmo grupo).
2. Filtra: `canRequestFocus`, `!skipTraversal`, `context != null`,
   `rect != Rect.zero`, `!isInSidebar(n)`.
3. `sameRow` = nós com sobreposição vertical (band) com `node`.
4. Se `node.rect.center.dx <= min(sameRow.center.dx) + 0.5` → é o mais à
   esquerda → edge.

Para card de carrossel: `nearestScope` = carrossel, `sameRow` = cards daquela
linha, `min` = primeiro card. Se atual = primeiro → edge → abre sidebar.
Se meio → não edge → move ← (default, `_ClampedTraversalPolicy` move ao
anterior). ✓

### Ponto 2 — → na sidebar fecha

`_SidebarEdgeAction.invoke(right)`:
- Se `isInSidebar(node)` → `onRightEdgeFromSidebar()` (`_closeSidebar`).
- Senão → `DirectionalFocusAction().invoke(intent)` (move → dentro do conteúdo).

### Ponto 4 — Back button

`HardwareKeyboard.instance.addHandler(_onHardwareKey)` em `initState`:
- Intercepta `LogicalKeyboardKey.goBack` (KeyDownEvent).
- Só trata se `isWide` (via `platformDispatcher.views.first`) E `_shellHasFocus()`
  (sidebar ou conteúdo com foco — não intercepta em telas de detalhe pushed).
- `_onBackButton()` + `return true` (consome → suppress system pop).

`_onBackButton()` (com debounce 300ms contra double-fire):
- Se `_sidebarOpen` → `_closeSidebar()`.
- Senão → `_openSidebar()`.

`PopScope(canPop: isWide ? false : location=='/')` — safety net: se o key
event não suprimir o system pop, `canPop:false` bloqueia exit no wide.

`_shellHasFocus()` = `sidebar.hasFocus || _contentScopeNode.hasFocus` —
garante que Back em tela de detalhe (fora do shell, sem foco no shell) não
seja interceptado (deixa o pop normal acontecer).

## Arquivos

- `lib/ui/navigation/side_bar.dart` — rewrite.
- `lib/ui/navigation/main_navigation_screen.dart` — rewrite.

## Verificação

```bash
flutter analyze && dart fix --apply && flutter analyze && flutter test
```

Teste manual TV:
1. Load → sidebar colapsada, foco no conteúdo.
2. ← no meio do carrossel → move entre cards (não abre sidebar).
3. ← no primeiro card → abre sidebar, foca item da rota ativa.
4. ↑↓ na sidebar → conteúdo atualiza imediatamente, sidebar continua aberta.
5. → na sidebar → fecha, foco volta ao último item do conteúdo.
6. Back (sidebar fechada) → abre sidebar imediatamente.
7. Back (sidebar aberta) → fecha + foco no conteúdo.
8. Select em item → fecha sidebar + foco no conteúdo.
