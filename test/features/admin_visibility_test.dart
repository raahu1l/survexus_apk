import 'package:flutter_test/flutter_test.dart';

void main() {
  group("Admin Panel visibility", () {
    test("Admin panel is hidden for non-admin users", () {
      final userRole = "user";

      final isAdminPanelVisible = userRole == "admin";

      expect(isAdminPanelVisible, false);
    });

    test("Admin panel is visible for admin users", () {
      final userRole = "admin";

      final isAdminPanelVisible = userRole == "admin";

      expect(isAdminPanelVisible, true);
    });
  });
}
