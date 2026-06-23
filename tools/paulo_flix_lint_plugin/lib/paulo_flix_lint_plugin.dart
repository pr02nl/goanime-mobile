/// Plugin de lint customizado para o projeto PauloFlix.
///
/// Define regras de AST analysis que detectam anti-patterns
/// comuns no projeto (ver `lib/src/`).
library;

import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/provider_context_read_inside_build.dart';

PluginBase createPlugin() => _PauloFlixLintPlugin();

class _PauloFlixLintPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) =>
      const [ProviderContextReadInsideBuild()];
}
