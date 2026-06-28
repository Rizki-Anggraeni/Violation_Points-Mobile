import 'dart:io' show Platform;
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Secara dinamis menentukan baseUrl.
  // Gunakan 10.0.2.2 untuk emulator Android agar bisa terhubung ke localhost komputer.
  // Gunakan localhost untuk platform lain (iOS simulator, desktop, dll).
  final String baseUrl = Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://127.0.0.1:3000';

  ApiService() {
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

  // Anda bisa menambahkan kembali fungsi getParentDashboardData di sini jika diperlukan
  // ...
}