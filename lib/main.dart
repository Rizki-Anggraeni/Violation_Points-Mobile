import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_ortu/services/api_service.dart';
import 'dart:developer';

// Import halaman, meskipun filenya belum ada, sesuai permintaan.
import 'package:mobile_ortu/pages/parent_dashboard_page.dart';
import 'package:mobile_ortu/pages/login_page.dart';

/// Kelas Notifier untuk mengelola status autentikasi.
class AuthNotifier with ChangeNotifier {
  String? _token;
  final _storage = const FlutterSecureStorage();

  String? get token => _token;

  /// Memeriksa apakah ada token yang tersimpan di storage saat aplikasi dimulai.
  Future<void> checkAutoLogin() async {
    _token = await _storage.read(key: 'jwt_token');
    notifyListeners();
  }

  /// Menghapus token dari storage dan state, lalu memberitahu listener.
  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    _token = null;
    notifyListeners();
  }
}

void main() async {
  // Wajib ada ini jika fungsi main() diubah jadi async
  WidgetsFlutterBinding.ensureInitialized(); 

  // SAKRAL: Inisialisasi data format tanggal bahasa Indonesia
  await initializeDateFormatting('id_ID', null); 

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthNotifier()),
        Provider(create: (_) => ApiService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Memaksa pengecekan berjalan aman tepat setelah widget pertama selesai di-render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAuth();
    });
  }

  Future<void> _initAuth() async {
    try {
      // Ambil context secara aman untuk membaca token
      if (mounted) {
        await Provider.of<AuthNotifier>(context, listen: false).checkAutoLogin();
      }
    } catch (e) {
      log("Error saat auto login", error: e);
    } finally {
      // Apapun yang terjadi (mau sukses atau error), loading WAJIB dimatikan biar gak stuck
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Sistem Poin Pelanggaran',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFF0F172A), // Slate 900
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF10B981), // Emerald 500
          ),
          useMaterial3: true,
        ),
        home: _isLoading
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : Consumer<AuthNotifier>(
                builder: (context, auth, _) {
                  // Jika token ada, tampilkan Dashboard. Jika tidak, tampilkan Login.
                  return auth.token != null
                      ? const ParentDashboardPage()
                      : const LoginPage();
                },
              ),
    );
  }
}