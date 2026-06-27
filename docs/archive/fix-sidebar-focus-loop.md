# Fix: Sidebar — ↑↓ não navega (target.onTap comentado) + redundância de onFocus

## Visão geral

3 bugs na sidebar que causam o "loop infinito" que você descreveu
(expandir uma vez, → colapsa sem selecionar nada, ↑↓ preso nos
ícones, ao trocar de tela o ciclo recomeça).

## Bugs identificados

### Bug 1 (causa raiz) — `_onItemFocus` tem `target.onTap(context)` comentado

`lib/ui/navigation/side_bar.dart:105-115`:

```dart
void _onItemFocus(int index) {
  // final target = _navItems[index];
  // if (!target.isSelected(widget.location)) {
  //   target.onTap(context); // context.go
  // }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && !_itemFocusNodes[index].hasFocus) {
      _itemFocusNodes[index].requestFocus(); // re-foca sempre
    }
  });
}
```

**Efeito**: ↑↓ na sidebar **só move o anel de foco** entre os 7 ícones.
**Não navega** (`context.go` está comentado). Combinado com o
re-foco pós-frame, isso resulta em: o foco fica preso na sidebar,
nada acontece, e o usuário precisa pressionar → para sair (que cai
no `_SidebarEdgeAction` → `_closeSidebar`).

Por que o `onFocus` está **comentado**: na v1 do design, "focar ≠
ativar" (Enter/Select selecionava). O skill de focus na sessão
2026-06-21 documentou que **essa hipótese estava errada** — o YouTube
TV real usa "**focar = ativar**" (↑↓ já navega). A correção para o
comportamento correto do YouTube TV é **descomentar o `onTap`** e
manter o re-foco pós-frame (para contrapor autofocus steal da nova
tela).

### Bug 2 (redundância) — `FocusableWidget.onFocus` chamado 2x

`lib/ui/core/widgets/focusable_widget.dart`:

- **Linha 62-76**: `_focusNode.addListener(_handleFocusChange)` —
  chama `widget.onFocus?.call()` quando `hasFocus` é true.
- **Linha 164-177**: `onFocusChange: (hasFocus) => ...` no `InkWell` —
  chama `widget.onFocus?.call()` DE NOVO.

**Efeito**: o callback do caller é invocado 2x a cada mudança de
foco. Para a sidebar, isso significa 2x `_onItemFocus` → 2x
`requestFocus` pós-frame → race com `_SidebarEdgeAction` em →
(que também agenda um `_closeSidebar` que tenta `_restoreContentFocus`,
e o `requestFocus` da sidebar pode ganhar).

Vou **remover o `onFocusChange` do `InkWell`** e manter só o listener
do `_focusNode`. O `onFocusChange` no `InkWell` é redundante
(cobertura dupla) e foi deixado ali por segurança — mas como o
listener já cobre, é só ruído.

### Bug 3 (UX) — `_closeSidebar` não foca o item correspondente do conteúdo

Você disse: "quando tento sair dele com a seta direita ele colapsa
mais não selecionada nada do widget".

`_closeSidebar` chama `_restoreContentFocus` que faz:

```dart
void _restoreContentFocus() {
  final last = _lastContentFocusNode;
  if (last != null && last.context != null) {
    last.requestFocus();
    return;
  }
  final primary = FocusManager.instance.primaryFocus;
  if (primary != null && primary.context != null &&
      _isInContentScope(primary)) {
    primary.requestFocus();
    return;
  }
  FocusManager.instance.primaryFocus?.unfocus();  // ← cai aqui
}
```

O `_lastContentFocusNode` é atualizado pelo `_onContentFocusChange`
(linha 73-80 do shell) que ouve `_contentScopeNode`. Mas o **foco
nunca foi para o conteúdo** desde que a sidebar foi aberta — então
`_lastContentFocusNode` pode estar válido (último widget de conteúdo
focado) ou não (primeira vez, sem foco prévio).

Quando cai em `unfocus()`, o d-pad fica "livre" e o próximo ↑
precisa "achar" o primeiro nó focável. Em alguns layouts, isso
pula para um widget de conteúdo que **não é o último selecionado**,
dando a impressão de "selecionou nada".

**Fix**: o `_lastContentFocusNode` deveria ser atualizado também
quando o foco entra/sai do shell, não só quando muda dentro do
`_contentScopeNode`. Vou fazer um fix simples: **no
`_openSidebar`, capturar o `primaryFocus` antes de mudar
qualquer coisa** e usar esse como `_lastContentFocusNode` no
`_closeSidebar`. Garante que sempre há um último válido.

## Decisões validadas

1. **Descomentar `_onItemFocus`**: navegação `↑↓` da sidebar
   chama `context.go(...)` (comportamento YouTube TV real).
   Mantém o re-foco pós-frame (anti-autofocus-steal).
2. **Remover `onFocusChange` redundante** do `InkWell` no
   `FocusableWidget`. O listener do `_focusNode` é suficiente.
3. **Capturar `primaryFocus` em `_openSidebar`** como fallback
   para `_lastContentFocusNode` no `_closeSidebar`.
4. **Cuidado com `_onItemFocus` vs `_onItemSelect`**: hoje eles
   têm responsabilidades diferentes. Quero manter essa divisão:
   - `_onItemFocus`: navegação (↑↓ no YouTube TV)
   - `_onItemSelect`: fecha a sidebar (Enter/Select/click)
   Vou **remover o `onTap` da `_onItemSelect`** quando já está
   na rota atual (hoje já é assim — verifica `isSelected`).
   Mas e quando ↑↓ vai para uma rota que **ainda não foi
   visitada**? Hoje o `_onItemSelect` chama `onTap` se não está
   selected. **Conclusão**: `_onItemSelect` está ok, não mexo.

## Estrutura de arquivos (mudanças)

| Arquivo | Mudança |
|---------|---------|
| `lib/ui/navigation/side_bar.dart` | Descomentar `target.onTap(context)` em `_onItemFocus` (linhas 106-109). |
| `lib/ui/core/widgets/focusable_widget.dart` | Remover o `onFocusChange:` callback do `InkWell` (linhas 164-177). Manter só o listener do `_focusNode` (linhas 62-76). |
| `lib/ui/navigation/main_navigation_screen.dart` | Em `_openSidebar`, capturar `primaryFocus` antes de `setState` e guardar como `_lastContentFocusNode` (caso ainda não esteja setado ou esteja null). |

## Algoritmos críticos

### Fix do `_onItemFocus` (sidebar)

```dart
void _onItemFocus(int index) {
  final target = _navItems[index];
  // ↑↓ = ativação (YouTube TV): navega IMEDIATAMENTE ao focar o item
  // se for uma rota diferente da atual. onTap usa context.go (não push).
  if (!target.isSelected(widget.location)) {
    target.onTap(context);
  }
  // Re-foca o item pós-frame: nova tela pode ter `autofocus` que rouba
  // foco. Pós-frame ganha a corrida e devolve o foco para a sidebar,
  // permitindo que o usuário continue ↑↓ sem perder a posição.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && !_itemFocusNodes[index].hasFocus) {
      _itemFocusNodes[index].requestFocus();
    }
  });
}
```

### Fix do `FocusableWidget` (remover `onFocusChange` redundante)

```dart
return Shortcuts(...,
  child: Actions(...,
    child: AnimatedBuilder(...,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: _isFocused
                  ? [BoxShadow(...)]
                  : null,
              border: _isFocused
                  ? Border.all(color: effectiveColor, width: 3)
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                focusNode: _focusNode,
                autofocus: widget.autoFocus,
                canRequestFocus: true,
                onTap: widget.onSelect,
                // SEM onFocusChange: a cobertura do focus é feita
                // pelo _focusNode.addListener em initState. Manter
                // onFocusChange aqui causaria chamada dupla de
                // widget.onFocus a cada mudança de foco.
                borderRadius: BorderRadius.circular(widget.borderRadius),
                splashColor: splash,
                highlightColor: highlight,
                child: Padding(
                  padding: widget.focusPadding,
                  child: widget.child,
                ),
              ),
            ),
          ),
        );
      },
    ),
  ),
);
```

### Fix do `_openSidebar` (capturar `primaryFocus` antes)

```dart
void _openSidebar() {
  if (_sidebarOpen) return;
  // Captura o foco atual ANTES de qualquer mudança — vai ser o alvo
  // do _restoreContentFocus quando a sidebar fechar (via → ou Back).
  // Garante que sempre há um último foco válido, mesmo na primeira
  // vez (quando _lastContentFocusNode ainda é null).
  final currentFocus = FocusManager.instance.primaryFocus;
  if (currentFocus != null && _isInContentScope(currentFocus)) {
    _lastContentFocusNode = currentFocus;
  }
  setState(() => _sidebarOpen = true);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _sidebarKey.currentState?.focusActiveItem();
  });
}
```

## Ordem de implementação

1. **Patch 1**: `side_bar.dart` — descomentar `_onItemFocus`.
2. **Patch 2**: `focusable_widget.dart` — remover `onFocusChange` redundante.
3. **Patch 3**: `main_navigation_screen.dart` — capturar `primaryFocus` em `_openSidebar`.
4. **Validação**: `flutter analyze` + `dart fix --apply` + `flutter test`.

## Verificação

- [ ] `flutter analyze` → 0 issues
- [ ] `dart fix --apply` → nada para arrumar
- [ ] `flutter test` → todos passando
- [ ] Repro manual em wide layout (TV/desktop):
  1. **Load**: sidebar colapsada, foco no conteúdo. ← → no meio do conteúdo
     move entre cards.
  2. **← edge**: sidebar expande, foco no item da rota ativa.
  3. **↑↓ na sidebar**: cada item **navega** imediatamente (conteúdo
     atualiza). Sidebar permanece expandida.
  4. **→ na sidebar**: sidebar colapsa, foco volta para o **último
     item de conteúdo** que estava focado antes de abrir.
  5. **Back (sidebar fechada)**: sidebar abre, foco no item da rota ativa.
  6. **Back (sidebar aberta)**: sidebar fecha, foco no conteúdo.
  7. **Enter/Select/click em item da sidebar**: navega (se não estiver
     na rota) + fecha a sidebar.

## Riscos & mitigações

- **Risco 1**: o `_onItemFocus` com `context.go` vai disparar
  navegação em TODA navegação ↑↓ — pode ser que o usuário
  queira só explorar sem navegar. **Mitigação**: o skill
  `youtube-tv-sidebar-pattern.md` documenta que **esse é o
  comportamento correto do YouTube TV real** (confirmado em
  teste de TV). Acostumar leva alguns dias.
- **Risco 2**: remover `onFocusChange` do `InkWell` pode quebrar
  algum call site que depende do callback visual (`_isFocused`
  sync). **Mitigação**: o listener já chama `setState(() => _isFocused = hasFocus)`
  (linha 68), o `onFocusChange` é literalmente idêntico em
  semântica. Não há perda de funcionalidade.
- **Risco 3**: capturar `primaryFocus` em `_openSidebar` pode
  pegar o foco do `FocusableWidget` da sidebar (que está
  chamando `_openSidebar` via _SidebarEdgeAction). **Mitigação**:
  o `_SidebarEdgeAction` é invocado quando o usuário aperta
  ← no edge do conteúdo — nesse momento o `primaryFocus` está
  no **conteúdo** (não na sidebar, que está colapsada). Seguro.

## Próximos passos (depois deste patch)

- Adicionar teste widget que simula `← ↑ ←` e verifica que
  o conteúdo realmente mudou de rota. Hoje só temos teste
  smoke ("monta sem erros").
- Adicionar teste para `FocusableWidget.onFocus` chamado
  exatamente 1x por mudança de foco.
