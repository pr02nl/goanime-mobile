import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/providers/theme_provider.dart';

void main() {
  group('ThemeProvider', () {
    test('deve iniciar com tema escuro por padrão', () {
      final themeProvider = ThemeProvider();
      expect(themeProvider.isDarkMode, true);
    });

    test('deve alternar tema corretamente', () {
      final themeProvider = ThemeProvider();
      
      // Inicialmente escuro
      expect(themeProvider.isDarkMode, true);
      
      // Alterna para claro
      themeProvider.toggleTheme();
      expect(themeProvider.isDarkMode, false);
      
      // Alterna para escuro novamente
      themeProvider.toggleTheme();
      expect(themeProvider.isDarkMode, true);
    });

    test('deve notificar listeners ao alternar tema', () {
      final themeProvider = ThemeProvider();
      int notifyCount = 0;
      
      themeProvider.addListener(() {
        notifyCount++;
      });
      
      themeProvider.toggleTheme();
      expect(notifyCount, 1);
      
      themeProvider.toggleTheme();
      expect(notifyCount, 2);
    });
  });
}
