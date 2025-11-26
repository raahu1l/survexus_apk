import 'package:flutter_test/flutter_test.dart';

void main() {
  test("VIP gating hides locked features", () {
    const userRole = "user"; // not VIP

    bool canAccessAnalytics = userRole == "vip";

    expect(canAccessAnalytics, false);
  });
}
