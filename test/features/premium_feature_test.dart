import 'package:flutter_test/flutter_test.dart';

bool canUsePremiumFeature({required bool isPremium}) {
  return isPremium == true;
}

void main() {
  test("Non-premium user cannot access premium feature", () {
    expect(canUsePremiumFeature(isPremium: false), false);
  });

  test("Premium user can access premium feature", () {
    expect(canUsePremiumFeature(isPremium: true), true);
  });
}
