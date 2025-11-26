import 'package:flutter/material.dart';

class AppStateProvider extends ChangeNotifier {
  // Auth state
  bool _isLoggedIn = false;
  String? _userId;

  // Role state
  String _role = 'guest'; // 'guest', 'user', 'admin'
  bool _isVIP = false;

  // Getters
  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String get role => _role;
  bool get isVIP => _isVIP;
  bool get isAdmin => _role == 'admin';
  bool get isGuest => _role == 'guest' || !_isLoggedIn;
  bool get isUser => _role == 'user' && _isLoggedIn;

  // Auth/Role setters
  void login(String userId, {String role = 'user', bool isVIP = false}) {
    _isLoggedIn = true;
    _userId = userId;
    _role = role;
    _isVIP = isVIP;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    _userId = null;
    _role = 'guest';
    _isVIP = false;
    notifyListeners();
  }

  void setRole(String newRole) {
    _role = newRole;
    notifyListeners();
  }

  void upgradeToVIP() {
    _isVIP = true;
    notifyListeners();
  }

  void downgradeFromVIP() {
    _isVIP = false;
    notifyListeners();
  }
}
