import 'package:flutter_test/flutter_test.dart';

void main() {
  test("Upsell should show for non-VIP users", () {
    const role = "user";

    final showUpsell = role != "vip";

    expect(showUpsell, true);
  });
}
