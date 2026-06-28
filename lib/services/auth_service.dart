import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

class AuthService with ChangeNotifier {
  final ApiService _apiService;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _isAuthenticated = false;
  bool _isLoading = true;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  AuthService(this._apiService);

  /// Cek apakah ada token yang tersimpan. Dibuat private.
  Future<void> _checkToken() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      _isAuthenticated = true;
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Fungsi publik untuk dipanggil oleh FutureBuilder di startup.
  Future<void> checkTokenStatus() async {
    // Cukup panggil versi private-nya.
    await _checkToken();
  }

  /// Fungsi untuk login
  Future<void> login(String username, String password) async {
    try {
      final bool loginSuccess = await _apiService.login(username, password);
      if (loginSuccess) {
        _isAuthenticated = true;
        notifyListeners();
      } else {
        throw Exception('Username atau password salah.');
      }
    } catch (e) {
      // Biarkan UI yang menangani tampilan error
      rethrow;
    }
  }

  /// Fungsi untuk logout
  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    _isAuthenticated = false;
    notifyListeners();
  }
}