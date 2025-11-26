import 'package:flutter_test/flutter_test.dart';

String getAccess(String role) {
  if (role == "guest") return "respond_only";
  if (role == "user") return "normal_access";
  if (role == "vip") return "full_access";
  return "unknown";
}

void main() {
  test("Guest role", () {
    expect(getAccess("guest"), "respond_only");
  });

  test("User role", () {
    expect(getAccess("user"), "normal_access");
  });

  test("VIP role", () {
    expect(getAccess("vip"), "full_access");
  });
}
