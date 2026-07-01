import 'dart:io' show Platform;
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_ortu/main.dart'; // Import main.dart untuk AuthNotifier

class ApiService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final AuthNotifier _authNotifier;

  // Secara dinamis menentukan baseUrl.
  // Gunakan 10.0.2.2 untuk emulator Android agar bisa terhubung ke localhost komputer.
  // Gunakan localhost untuk platform lain (iOS simulator, desktop, dll).
  final String baseUrl = Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://127.0.0.1:3000';

  ApiService({required AuthNotifier authNotifier}) : _authNotifier = authNotifier {
    // Interceptor untuk menambahkan token secara otomatis ke setiap request
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Selalu set header Accept
        options.headers['Accept'] = 'application/json';

        // Baca token dari storage
        final token = await _storage.read(key: 'jwt_token');

        // Jika token ada, tambahkan ke header Authorization
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        // Lanjutkan request
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // Jika respons adalah 401 (Unauthorized)
        if (e.response?.statusCode == 401) {
          log("Token tidak valid atau kedaluwarsa. Melakukan logout...");
          // Panggil fungsi logout dari AuthNotifier
          await _authNotifier.logout();
          // Jangan lanjutkan error ke UI, karena sudah ditangani dengan logout.
          return; // Keluar dari interceptor
        }
        // Untuk error lain, teruskan saja agar bisa ditangani oleh UI jika perlu.
        return handler.next(e);
      },
    ));
  }

  /// Fungsi untuk login.
  /// Mengembalikan true jika berhasil, false jika gagal.
  Future<bool> login(String username, String password) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/auth/login',
        data: {'username': username, 'password': password},
      );

      if (response.statusCode == 200 && response.data['token'] != null) {
        // Jika berhasil, simpan token dan kembalikan true
        await _storage.write(key: 'jwt_token', value: response.data['token']);
        return true;
      } else {
        // Jika respons tidak sesuai harapan
        return false;
      }
    } on DioException catch (e) {
      // Jika terjadi error saat request (misal: password salah, server down)
      log('Login error', error: e);
      return false;
    }
  }

  /// Mengambil daftar semua pelanggaran.
  Future<dynamic> getViolations() async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/violations',
      );
      return response.data;
    } on DioException catch (e) {
      // Menangani error spesifik dari Dio
      log('Error fetching violations', error: e);
      // Melempar kembali error agar UI bisa menanganinya
      rethrow;
    }
  }

  /// Mengambil daftar semua data presensi.
  Future<dynamic> getAttendances() async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/attendances', // Asumsi endpoint presensi
      );
      return response.data;
    } on DioException catch (e) {
      // Menangani error spesifik dari Dio
      log('Error fetching attendances', error: e);
      // Melempar kembali error agar UI bisa menanganinya
      rethrow;
    }
  }

  /// Mengambil daftar semua jadwal pelajaran.
  Future<dynamic> getSchedules() async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/schedules', // Asumsi endpoint jadwal
      );
      return response.data;
    } on DioException catch (e) {
      // Menangani error spesifik dari Dio
      log('Error fetching schedules', error: e);
      // Melempar kembali error agar UI bisa menanganinya
      rethrow;
    }
  }

  /// Mengambil daftar siswa yang terhubung dengan orang tua.
  Future<dynamic> getStudents() async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/students', // Asumsi endpoint untuk data siswa
      );
      return response.data;
    } on DioException catch (e) {
      // Menangani error spesifik dari Dio
      log('Error fetching students', error: e);
      // Melempar kembali error agar UI bisa menanganinya
      rethrow;
    }
  }

  /// Mengambil daftar semua aturan pelanggaran.
  Future<dynamic> getViolationRules() async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/violation-rules', // Endpoint untuk aturan
      );
      return response.data;
    } on DioException catch (e) {
      // Menangani error spesifik dari Dio
      log('Error fetching violation rules', error: e);
      // Melempar kembali error agar UI bisa menanganinya
      rethrow;
    }
  }

  /// Mengirimkan FCM token ke backend untuk disimpan.
  Future<void> updateFCMToken(String fcmToken) async {
    // Token JWT akan ditambahkan secara otomatis oleh interceptor.
    try {
      // Menggunakan PUT sesuai dengan definisi di userRoutes.js
      await _dio.put(
        '$baseUrl/api/users/fcm-token',
        data: {'fcmToken': fcmToken},
      );
      log('FCM token berhasil dikirim ke backend.');
    } on DioException catch (e) {
      // Jangan rethrow error jika status 401, karena sudah ditangani interceptor.
      // Untuk error lain, kita hanya log saja agar tidak mengganggu user.
      log('Gagal mengirim FCM token: ${e.message}');
    }
  }

  // Anda bisa menambahkan kembali fungsi getParentDashboardData di sini jika diperlukan
  // ...
}