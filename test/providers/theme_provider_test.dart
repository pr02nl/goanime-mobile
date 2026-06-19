import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/ui/settings/view_models/theme_viewmodel.dart';

void main() {
  group('ThemeViewModel', () {
    test('deve iniciar com tema escuro por padrão', () {
      final themeViewModel = ThemeViewModel();
      expect(themeViewModel.isDarkMode, true);
    });

    test('deve alternar tema corretamente', () {
      final themeViewModel = ThemeViewModel();

      // Inicialmente escuro
      expect(themeViewModel.isDarkMode, true);

      // Alterna para claro
      themeViewModel.toggleTheme();
      expect(themeViewModel.isDarkMode, false);

      // Alterna para escuro novamente
      themeViewModel.toggleTheme();
      expect(themeViewModel.isDarkMode, true);
    });

    test('deve notificar listeners ao alternar tema', () {
      final themeViewModel = ThemeViewModel();
      int notifyCount = 0;

      themeViewModel.addListener(() {
        notifyCount++;
      });

      themeViewModel.toggleTheme();
      expect(notifyCount, 1);

      themeViewModel.toggleTheme();
      expect(notifyCount, 2);
    });
  });
}
