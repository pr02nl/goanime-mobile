/// Regra: detecta `context.read<...>()` dentro do `build` method de um
/// widget que cria um `Provider` (ou `ChangeNotifierProvider`,
/// `MultiProvider`).
///
/// **Por que essa regra existe:**
///
/// O `context` passado para o `build` method é ancestral do
/// `Provider` que está sendo criado no mesmo método. Conforme a
/// doc do `package:provider`:
///
/// > "Make sure that Foo is under your MultiProvider/Provider.
/// > This usually happens when you are creating a provider and
/// > trying to read it immediately. The context you are using
/// > is associated to the widget that is the parent of Provider."
///
/// Isso causa `ProviderNotFoundException` em runtime.
///
/// **O fix correto:** passar o `BuildContext` do `create:` callback,
/// que tem acesso aos providers ancestrais:
///
/// ```dart
/// // ERRADO
/// return ChangeNotifierProvider(
///   create: (_) => ViewModel(
///     repo: context.read<MyRepository>(), // ← ancestor do Provider
///   ),
/// );
///
/// // CERTO
/// return ChangeNotifierProvider(
///   create: (ctx) => ViewModel(
///     repo: ctx.read<MyRepository>(), // ← ctx vem acima do Provider
///   ),
/// );
/// ```
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Lint code registrado em `paulo_flix_lint_plugin.dart`.
const LintCode providerContextReadInsideBuild = LintCode(
  name: 'provider_context_read_inside_build',
  problemMessage:
      'context.read<...>() dentro do `build` de um widget que cria um Provider '
      'causa ProviderNotFoundException em runtime.',
  correctionMessage:
      'Use o `ctx` do `create:` callback do Provider — ele tem acesso aos '
      'providers ancestrais. Ex: `create: (ctx) => ViewModel(repo: '
      'ctx.read<MyRepository>())`.',
  url: 'https://pub.dev/packages/provider#common-problems (search for '
      '"ProviderNotFoundException")',
);

class _BuildMethodVisitor extends RecursiveAstVisitor<void> {
  _BuildMethodVisitor(this.reporter);
  final ErrorReporter reporter;

  /// Detecta `context.read<...>()` (chamada de método).
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isContextReadInvocation(node)) {
      reporter.atNode(node, providerContextReadInsideBuild);
    }
    super.visitMethodInvocation(node);
  }

  bool _isContextReadInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    if (methodName != 'read' &&
        methodName != 'watch' &&
        methodName != 'select') {
      return false;
    }
    final target = node.target;
    if (target is! SimpleIdentifier) return false;
    return target.name == 'context';
  }
}

class ProviderContextReadInsideBuild extends DartLintRule {
  const ProviderContextReadInsideBuild()
      : super(
          code: providerContextReadInsideBuild,
        );

  @override
  List<String> get filesToAnalyze => const ['**/*.dart'];

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Itera sobre todas as `MethodDeclaration` do arquivo
    // analisado. `DartLintRule` chama `run` 1x por arquivo e
    // expõe o AST via `resolver` — mas a API 0.7.5 não dá um
    // helper para "iterar todos os métodos", então usamos o
    // registry do CustomLintContext.
    final registry = context.registry;
    // Adiciona listener para todos os `MethodDeclaration` do arquivo.
    registry.addMethodDeclaration((node) {
      if (node.name.lexeme != 'build') return;
      _checkBuildMethod(node, reporter);
    });
  }

  void _checkBuildMethod(MethodDeclaration build, ErrorReporter reporter) {
    // 1. Verifica se é um `build(BuildContext context)`.
    final params = build.parameters;
    if (params == null || params.parameters.isEmpty) return;
    if (params.parameters.first.name?.lexeme != 'context') return;

    final body = build.body;
    if (body is! BlockFunctionBody) return;

    // 2. Verifica se retorna Provider/ChangeNotifierProvider/MultiProvider.
    final returnStmt = _findReturnStatement(body);
    if (returnStmt == null) return;
    if (!_isProviderConstruction(returnStmt.expression)) return;

    // 3. Procura `context.read<...>()` no body.
    final visitor = _BuildMethodVisitor(reporter);
    body.accept(visitor);
  }

  ReturnStatement? _findReturnStatement(BlockFunctionBody body) {
    for (final stmt in body.block.statements) {
      if (stmt is ReturnStatement) return stmt;
    }
    return null;
  }

  /// `true` se `expr` é uma construção de Provider.
  bool _isProviderConstruction(Expression? expr) {
    if (expr is! InstanceCreationExpression) return false;
    final type = expr.constructorName.type;
    final name = type.name2.lexeme;
    return name == 'Provider' ||
        name == 'ChangeNotifierProvider' ||
        name == 'MultiProvider';
  }
}
