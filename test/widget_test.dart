import 'package:financer/main.dart';
import 'package:financer/services/storage_service.dart';
import 'package:financer/services/theme_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('finance dashboard renders', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = await StorageService.init();
    final themeController = await ThemeController.init();

    await tester.pumpWidget(
      FinanceApp(storage: storage, themeController: themeController),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personal Finance'), findsOneWidget);
    expect(find.text('Unplanned / Surplus Buffer'), findsOneWidget);
  });
}
