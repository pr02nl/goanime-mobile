# Plano: Navegação estilo YouTube TV no `MainNavigationScreen`

## Objetivo

Reproduzir o comportamento de navegação do YouTube TV no shell de navegação do
GoAnime Mobile (`lib/ui/navigation/main_navigation_screen.dart` +
`lib/ui/navigation/side_bar.dart`).

## Comportamento alvo (YouTube TV)

1. **Load inicial**: sidebar **colapsada** (só ícones, 72px) + **foco no conteúdo**.
2. **← no conteúdo**: sidebar **expande** (220px, ícones + labels) + foco vai para o
   item da rota ativa.
3. **↑↓ na sidebar**: move entre itens com anel de foco visível. Sidebar permanece
   expandida. **Focar ≠ ativar** — nada navega só por focar.
4. **→ na sidebar**: sidebar **colapsa** + foco **volta ao conteúdo**.
5. **Enter/Select na sidebar**: navega para a seção + sidebar **colapsa** + foco
   **vai ao conteúdo** da nova seção.
6. **Hover/foco em item colapsado**: tooltip com o label (já existe hoje).

## Diagnóstico do estado atual

### 🔴 CRÍTICO 1 — `onFocus: onTap` dispara navegação ao focar

`side_bar.dart` → `_SidebarItem`:

```dart
return FocusableWidget(
  onSelect: onTap,
  onFocus: onTap,        // ← BUG: focar já aciona context.go/push
  autoFocus: selected,
  ...
);
```

`FocusableWidget` chama `widget.onFocus?.call()` sempre que o nó ganha foco
(`focusable_widget.dart:71` e `:172`). Com `onFocus: onTap`, **todo ↑↓ pela
sidebar navega sem confirmação**. No YouTube TV, focar é diferente de ativar.

### 🔴 CRÍTICO 2 — `autoFocus: selected` rouba o foco do conteúdo no load

No load, o item "Início" (`selected: location == '/'`) tem `autoFocus: true` →
a sidebar captura o foco imediatamente. Combinado com o bug #1, `context.go('/')`
é re-disparado no load. No YouTube TV, o foco inicial é **sempre no conteúdo**.

### 🔴 CRÍTICO 3 — `_SidebarEdgeAction` existe mas NÃO está conectado

`main_navigation_screen.dart:120-144` define `_SidebarEdgeAction` (← expande,
→ colapsa) mas `_buildWideLayout` (linhas 66-81) **não o conecta** via `Actions`.
Resultado:
- ← no conteúdo **não expande** a sidebar.
- → na sidebar **não colapsa** nem devolve foco ao conteúdo.
- `_expandSidebar()` é definido mas **nunca chamado** → `_sidebarExpanded`
  permanece `false` para sempre. A sidebar nunca expande na prática.

### 🟡 MÉDIO 4 — Colapso só ao selecionar item, não ao perder foco

`onClose: _collapseSidebar` só roda no `onTap` dos itens. Sair da sidebar com →
não colapsa. No YouTube TV, a sidebar colapsa **ao perder foco**.

### 🟡 MÉDIO 5 — Foco não volta ao conteúdo ao selecionar item

Ao ativar "Buscar", `context.push('/search')` navega mas o foco permanece na
sidebar. No YouTube TV, o foco vai ao **conteúdo** da nova seção.

### 🟡 MÉDIO 6 — `selected` e `focused` convergem indevidamente

Como `onFocus: onTap` dispara `context.go`, focar "Ajustes" muda `selected` em
tempo real. No YouTube TV, `selected` (rota ativa, destaque persistente) e
`focused` (anel temporário do d-pad) são **independentes**.

### 🟢 BAIXO 7 — Logo no topo da sidebar está comentado (`side_bar.dart:52-62`)

### 🟢 BAIXO 8 — Sidebar sem scroll vertical (estoura se crescer)

## Matriz de divergência

| YouTube TV | Atual | Sev |
|---|---|---|
| Foco inicial no conteúdo | ❌ Foco na sidebar | 🔴 |
| Focar ≠ ativar | ❌ onFocus navega | 🔴 |
| ← expande sidebar | ❌ Action não conectado | 🔴 |
| → colapsa + volta ao conteúdo | ❌ Não implementado | 🔴 |
| Select navega + colapsa + foco no conteúdo | ⚠️ Navega+colapsa, foco fica na sidebar | 🟡 |
| Sidebar colapsa ao perder foco | ❌ Só ao selecionar | 🟡 |
| selected ≠ focused | ❌ Conflitam via onFocus | 🟡 |
| Logo no topo | ❌ Comentado | 🟢 |
| Scroll vertical | ❌ Ausente | 🟢 |

## Arquitetura de foco proposta

### Princípio

- **Foco inicial**: responsabilidade do **conteúdo** (`widget.child`). O shell
  **não** força autofocus na sidebar. Se a tela do conteúdo não tiver
  autofocus próprio, o shell aplica um **fallback pós-frame**: se o foco
  estiver na sidebar após o primeiro frame, move para o conteúdo.
- **Expansão da sidebar**: ligada ao **foco do grupo da sidebar**, não a um
  state manual. O `_SidebarState` mantém um `FocusNode` do grupo e ouve
  `hasFocus` → expande/colapsa automaticamente. `_sidebarExpanded` deixa de
  ser state do pai e vira state interno da sidebar (ou permanece no pai mas
  sincronizado via callback `onFocusChange` do grupo).
- **← do conteúdo → sidebar**: `_SidebarEdgeAction` no `_buildWideLayout`,
  `onLeftEdge: _expandSidebar + focar item ativo`.
- **→ da sidebar → conteúdo**: tratado dentro da sidebar. Quando o item ativo
  recebe → no seu limite direito (ou sempre, para simplificar), a sidebar
  colapsa e `unfocus()` devolve o foco ao conteúdo.
- **Select em item**: `onSelect` (não `onFocus`) → `context.go/push` +
  `_collapseSidebar` + `FocusScope.of(context).unfocus()` (ou
  `contentFocusNode.requestFocus()` se mantivermos um nó explícito).

### Decisão de implementação (a confirmar com usuário)

**Opção A (mais simples, recomendada):** sidebar expande/colapsa por foco do
grupo, sem `contentFocusNode` explícito. Devolução de foco ao conteúdo via
`FocusScope.of(context).unfocus()` — o Flutter move o foco para o ancestral
mais próximo que pode recebê-lo, e o conteúdo tem seus próprios focusables.

**Opção B (mais explícita):** shell mantém `FocusNode _contentFocusNode`,
passa para o conteúdo via `FocusScope(node: _contentFocusNode, child:
widget.child)`. Ao selecionar item da sidebar, chama
`_contentFocusNode.requestFocus()`.

> Recomendo **Opção A** — menos código, alinha com o padrão Flutter de
> `unfocus()` devolver foco ao escopo ancestral. Se o fallback pós-frame
> mostrar que o conteúdo não recupera foco, migramos para B.

## Plano de implementação

### Fase 1 — Corrigir bugs críticos (shell + sidebar)

Arquivos: `main_navigation_screen.dart`, `side_bar.dart`.

**Passo 1.1 — `_SidebarItem`: separar foco de ativação**
- Remover `onFocus: onTap` (focar não navega).
- Remover `autoFocus: selected` (foco inicial não é na sidebar).
- Manter `onSelect: onTap` (Select/Enter/click ativam).
- `selected` continua sendo só indicador visual da rota ativa.

**Passo 1.2 — Sidebar expande/colapsa por foco do grupo**
- `_SidebarState`: adicionar `FocusNode _sidebarGroupFocusNode`.
- Listener: `hasFocus` true → expande; false → colapsa.
- Remover a dependência do `_sidebarExpanded` do pai (ou mantê-lo
  sincronizado via callback `onExpandChange` para o pai poder reagir).
- `AnimatedContainer` já faz a animação de largura.

**Passo 1.3 — Conectar `_SidebarEdgeAction` no `_buildWideLayout`**
- Envolver o `Row` (ou o conteúdo) em `Actions` com
  `DirectionalFocusIntent: _SidebarEdgeAction(onLeftEdge: _expandSidebar)`.
- `onLeftEdge`: além de expandir, **focar o item da rota ativa** da sidebar
  (encontrar o `_SidebarItem` com `selected == true` e chamar
  `requestFocus` no `FocusNode` dele).
- `onRightEdge`: null no conteúdo (→ no conteúdo não faz nada especial).
- Para o → na sidebar colapsar e voltar ao conteúdo: o
  `_SidebarEdgeAction` da sidebar (separado, dentro da sidebar) ou o
  `FocusTraversalGroup` natural resolve — ao chegar no item mais à direita,
  → move para o conteúdo (que está à direita na `Row`). Precisamos garantir
  que isso colapse a sidebar: como a sidebar colapsa ao perder foco (passo
  1.2), o → natural que move o foco para o conteúdo já colapsa
  automaticamente. ✅

**Passo 1.4 — Select em item: navegar + colapsar + foco no conteúdo**
- `onTap` do `_SidebarItem`: `context.go/push(...)` + (a sidebar colapsa
  automaticamente ao perder foco, passo 1.2) +
  `FocusScope.of(context).unfocus()` para devolver foco ao conteúdo.
- Remover `widget.onClose()` explícito nos `onTap` (a sidebar colapsa sozinha
  ao perder foco). Ou manter como belt-and-suspenders.

**Passo 1.5 — Fallback de foco inicial no conteúdo**
- `_MainNavigationScreenState.initState` + postFrameCallback:
  - Se `isWide` e o foco primário estiver na sidebar (não no conteúdo),
    `FocusScope.of(context).unfocus()` para o conteúdo pegar.
  - Idealmente, o conteúdo já tem autofocus (NetflixHeroCard, primeiro
    carousel). Se não, o fallback resolve.
- Não adicionar `autofocus: true` no shell para não competir com autofocus
  internos das telas.

### Fase 2 — Polimento (opcional, confirmar)

**Passo 2.1 — Restaurar logo no topo da sidebar**
- Descomentar/adaptar o bloco de logo (`side_bar.dart:52-62`).
- Tornar o logo não-focusable (visual only).

**Passo 2.2 — Scroll vertical na sidebar**
- Envolver a `Column` dos itens em `SingleChildScrollView` ou usar `ListView`
  para suportar mais itens sem estourar.

### Verificação (obrigatória ao final)

```bash
flutter analyze          # 0 issues
dart fix --apply         # mechanical fixes
flutter analyze          # confirmar green após dart fix
flutter test             # 0 failures
```

**Teste manual (TV/desktop):**
1. Load → sidebar colapsada, foco no conteúdo (primeiro card/hero).
2. ← no conteúdo → sidebar expande, foco no item da rota ativa.
3. ↑↓ na sidebar → move entre itens, nada navega sem Enter.
4. → na sidebar → colapsa, foco volta ao conteúdo.
5. Enter em "Buscar" → vai para /search, sidebar colapsa, foco no campo de
   busca ou primeiro card.
6. Hover/foco em item colapsado → tooltip com label.

## Riscos & mitigações

| Risco | Mitigação |
|---|---|
| `unfocus()` não devolve foco ao conteúdo se nenhuma tela tiver autofocus | Fallback pós-frame no shell; se insuficiente, migrar para Opção B (`contentFocusNode` explícito) |
| `FocusTraversalGroup` da sidebar impede ← de sair para o conteúdo | O grupo da sidebar permite escape horizontal (←/→ delegam ao escopo pai); o `_SidebarEdgeAction` no `_buildWideLayout` captura o ← no conteúdo |
| Animação de expansão conflict com focus listener (loop) | Usar `notifyListeners` do FocusNode com guarda `if (mounted && _isFocused != hasFocus)` |
| `_SidebarItem` perde `autoFocus` e a sidebar nunca recebe foco inicial | Correto — é o objetivo. ← do conteúdo move o foco explicitamente para o item ativo via `_SidebarEdgeAction.onLeftEdge` |

## Itens fora de escopo (não alterar)

- Breakpoint `>= 600px` para layout wide (mantém como está).
- Lista de itens da sidebar (Início, Animes, Filmes, Buscar, Favoritos,
  Downloads, Ajustes) — comportamento, não itens.
- Drawer mobile (`_DrawerMenu`) — não muda nesta iteração.
- `FocusableWidget`, `KeyActivable` — não alterar.
- Telas de conteúdo (HomeScreen, SearchScreen, etc.) — só garantias de foco
  via fallback, sem refatorar.

## Ordem de execução

1. Aprovação deste plano.
2. Passo 1.1 (remover onFocus/autoFocus da sidebar) → `flutter analyze`.
3. Passo 1.2 (expande/colapsa por foco) → `flutter analyze`.
4. Passo 1.3 (conectar _SidebarEdgeAction) → `flutter analyze`.
5. Passo 1.4 (Select + foco conteúdo) → `flutter analyze`.
6. Passo 1.5 (fallback foco inicial) → `flutter analyze`.
7. `flutter analyze` + `dart fix --apply` + `flutter analyze` + `flutter test`.
8. (Se aprovado) Fase 2: logo + scroll.
9. Documentar em `docs/TV_NAVIGATION_YOUTUBE.md` para sessões futuras.
