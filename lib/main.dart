import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mobile_ortu/services/api_service.dart';

// Import halaman, meskipun filenya belum ada, sesuai permintaan.
import 'package:mobile_ortu/pages/parent_dashboard_page.dart';
import 'package:mobile_ortu/pages/login_page.dart';
import 'package:provider/provider.dart';

/// Definisikan channel notifikasi untuk Android.
/// Ini penting agar notifikasi bisa muncul sebagai pop-up (heads-up notification).
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // id
  'High Importance Notifications', // title
  description: 'This channel is used for important notifications.', // description
  importance: Importance.high,
);

/// Inisialisasi plugin untuk notifikasi lokal.
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Handler untuk pesan FCM saat aplikasi berjalan di background.
/// Wajib berada di top-level (di luar class).
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Pastikan Firebase sudah diinisialisasi
  await Firebase.initializeApp();
  // Di sini Anda juga bisa menambahkan logika untuk menampilkan notifikasi lokal jika diperlukan.
  print('Ada pesan masuk di background: ${message.messageId}');
}

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

// Kunci global untuk Navigator, agar bisa diakses dari mana saja.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Wajib ada ini jika fungsi main() diubah jadi async
  WidgetsFlutterBinding.ensureInitialized(); 

  // Inisialisasi Firebase
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  // Buat channel notifikasi di perangkat.
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Konfigurasi Firebase agar menggunakan setelan notifikasi foreground dari kita.
  // Ini memungkinkan kita untuk menampilkan notifikasi kustom saat aplikasi terbuka.
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // SAKRAL: Inisialisasi data format tanggal bahasa Indonesia
  await initializeDateFormatting('id_ID', null); 
  
  final authNotifier = AuthNotifier();
  // Penting: Lakukan pengecekan login di sini, sebelum aplikasi berjalan
  await authNotifier.checkAutoLogin();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authNotifier),
        // Berikan instance AuthNotifier ke ApiService
        Provider(create: (_) => ApiService(authNotifier: authNotifier)),
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
  @override
  void initState() {
    super.initState();
    _initFCM();

    // Tambahkan listener ke AuthNotifier.
    // Ini akan dieksekusi setiap kali status login berubah.
    context.read<AuthNotifier>().addListener(_onAuthStateChanged);
  }

  @override
  void dispose() {
    // Hapus listener saat widget tidak lagi digunakan untuk mencegah memory leak.
    context.read<AuthNotifier>().removeListener(_onAuthStateChanged);
    super.dispose();
  }

  /// Inisialisasi Firebase Cloud Messaging (FCM)
  Future<void> _initFCM() async {
    // 1. Minta izin notifikasi ke pengguna
    await FirebaseMessaging.instance.requestPermission();

    // 2. Ambil token unik perangkat ini
    final String? token = await FirebaseMessaging.instance.getToken();

    if (token != null) {
      // 3. Cetak token ke konsol untuk debugging
      print('====== TOKEN FCM HP INI ======');
      print(token);
      print('==============================');

      // 4. Kirim token ke backend jika user SUDAH dalam keadaan login saat aplikasi dibuka.
      // Menggunakan `context.read` adalah cara aman untuk mengakses provider di dalam initState.
      final auth = context.read<AuthNotifier>();
      if (auth.token != null) {
        final apiService = context.read<ApiService>();
        await apiService.updateFCMToken(token);
      }
    }

    // 5. Tambahkan listener untuk pesan yang masuk saat aplikasi terbuka (foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Ada pesan masuk di foreground: ${message.notification?.title}');
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      // Jika ada notifikasi, tampilkan menggunakan flutter_local_notifications
      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: 'launch_background', // Pastikan ada drawable 'launch_background'
            ),
          ),
        );
      }
    });
  }

  /// Fungsi yang akan dipanggil setiap kali status autentikasi berubah.
  void _onAuthStateChanged() async {
    final auth = context.read<AuthNotifier>();
    // Jika user baru saja login (token menjadi tidak null)
    if (auth.token != null) {
      final String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        final apiService = context.read<ApiService>();
        print('User baru login, mengirimkan FCM token ke backend...');
        await apiService.updateFCMToken(fcmToken);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Sistem Poin Pelanggaran',
        navigatorKey: navigatorKey, // Daftarkan navigatorKey di sini
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFF0F172A), // Slate 900
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF10B981), // Emerald 500
          ),
          useMaterial3: true,
        ),
        // Gunakan Consumer untuk secara reaktif memilih halaman yang ditampilkan
        home: Consumer<AuthNotifier>(
          builder: (context, auth, _) {
            // Jika token ada, tampilkan Dashboard. Jika tidak, tampilkan Login.
            return auth.token != null ? const ParentDashboardPage() : const LoginPage();
          },
        ),
    );
  }
}