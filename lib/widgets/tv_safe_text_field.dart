import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TextField que funciona corretamente com controle remoto de TV (D-pad)
/// e teclado de desktop.
///
/// **O problema**: Um [TextField] padrão no Flutter captura as teclas de seta
/// para movimentação do cursor de texto. Em uma TV com controle remoto,
/// o usuário fica **preso** no campo — não consegue navegar para os resultados
/// de busca ou outros widgets usando as setas.
///
/// **A solução**: Este widget intercepta os eventos de tecla no [FocusNode]
/// antes que cheguem ao [TextField]. Quando uma seta direcional é pressionada:
/// - **Seta para baixo/direita**: Sai do campo e move o foco para o próximo
///   widget na direção indicada (resultados de busca, botões, etc.).
/// - **Seta para cima**: Se for a primeira ação, sai do campo e move para cima.
/// - **ESC/Back**: Desfoca o campo (unfocus).
/// - **Enter**: Submete a busca em vez de inserir uma quebra de linha.
///
/// Em mobile (sem teclado físico), o widget se comporta como um [TextField]
/// normal — o teclado virtual aparece e o usuário usa touch para navegar.
class TVSafeTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final TextStyle? style;
  final InputDecoration? decoration;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final TextInputAction textInputAction;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Color? cursorColor;
  final bool obscureText;

  /// Nó de foco para o qual mover quando o usuário pressiona seta para baixo
  /// enquanto o campo está focado. Útil para pular direto para o primeiro
  /// resultado de busca.
  final FocusNode? downFocusNode;

  /// Nó de foco para o qual mover quando o usuário pressiona seta para cima.
  final FocusNode? upFocusNode;

  /// Nó de foco para o qual mover quando o usuário pressiona seta para a
  /// direita (quando o cursor está no fim do texto).
  final FocusNode? rightFocusNode;

  /// Nó de foco para o qual mover quando o usuário pressiona seta para a
  /// esquerda (quando o cursor está no início do texto).
  final FocusNode? leftFocusNode;

  /// Se verdadeiro, ESC desfoca o campo. Padrão: true.
  final bool escapeToUnfocus;

  const TVSafeTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.style,
    this.decoration,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.textInputAction = TextInputAction.search,
    this.prefixIcon,
    this.suffixIcon,
    this.cursorColor,
    this.downFocusNode,
    this.upFocusNode,
    this.rightFocusNode,
    this.leftFocusNode,
    this.escapeToUnfocus = true,
    this.obscureText = false,
  });

  @override
  State<TVSafeTextField> createState() => _TVSafeTextFieldState();
}

class _TVSafeTextFieldState extends State<TVSafeTextField> {
  late FocusNode _focusNode;
  late TextEditingController _controller;
  bool _ownsFocusNode = false;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode(debugLabel: 'TVSafeTextField');
      _ownsFocusNode = true;
    }
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsFocusNode) _focusNode.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  /// Intercepta teclas direcionais ANTES de chegarem ao EditableText.
  ///
  /// Retorna [KeyEventResult.handled] para consumir o evento (impede que
  /// o TextField mova o cursor), ou [KeyEventResult.ignored] para deixar
  /// o Flutter tratar normalmente (ex: letras, backspace).
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // ESC → desfoca o campo (sai do modo de edição)
    if (widget.escapeToUnfocus &&
        (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.goBack)) {
      _focusNode.unfocus();
      return KeyEventResult.handled;
    }

    // Enter → submete a busca em vez de quebrar linha
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA) {
      widget.onSubmitted?.call(_controller.text);
      return KeyEventResult.handled;
    }

    // As setas só são interceptadas se houver um nó de destino definido.
    // Se não houver, deixamos o TextField tratar (mover cursor) normalmente.
    switch (key) {
      case LogicalKeyboardKey.arrowDown:
        if (widget.downFocusNode != null) {
          _focusNode.unfocus();
          widget.downFocusNode!.requestFocus();
          return KeyEventResult.handled;
        }
        // Sem nó de destino: tenta mover no traversal order
        _focusNode.unfocus(
          disposition: UnfocusDisposition.scope,
        );
        FocusScope.of(context).nextFocus();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowUp:
        if (widget.upFocusNode != null) {
          _focusNode.unfocus();
          widget.upFocusNode!.requestFocus();
          return KeyEventResult.handled;
        }
        _focusNode.unfocus(
          disposition: UnfocusDisposition.scope,
        );
        FocusScope.of(context).previousFocus();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowRight:
        // Só sai do campo se o cursor estiver no fim do texto
        final selection = _controller.selection;
        if (selection.isValid &&
            selection.extentOffset == _controller.text.length) {
          if (widget.rightFocusNode != null) {
            _focusNode.unfocus();
            widget.rightFocusNode!.requestFocus();
            return KeyEventResult.handled;
          }
        }
        break;

      case LogicalKeyboardKey.arrowLeft:
        // Só sai do campo se o cursor estiver no início do texto
        final selection = _controller.selection;
        if (selection.isValid && selection.extentOffset == 0) {
          if (widget.leftFocusNode != null) {
            _focusNode.unfocus();
            widget.leftFocusNode!.requestFocus();
            return KeyEventResult.handled;
          }
        }
        break;
    }

    // Deixa o TextField tratar o resto (letras, números, backspace, etc.)
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: widget.style,
        obscureText: widget.obscureText,
        decoration: widget.decoration ??
            InputDecoration(
              hintText: widget.hintText,
              prefixIcon: widget.prefixIcon,
              suffixIcon: widget.suffixIcon,
              border: InputBorder.none,
            ),
        textInputAction: widget.textInputAction,
        cursorColor: widget.cursorColor,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}
