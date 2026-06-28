import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import AuthNotifier dari main.dart dan ApiService
import 'package:mobile_ortu/main.dart';
import 'package:mobile_ortu/services/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Fungsi untuk menangani proses login
  Future<void> _handleLogin() async {
    // Validasi form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Ambil ApiService dari Provider, jangan buat instance baru.
      final apiService = Provider.of<ApiService>(context, listen: false);

      // Panggil fungsi login dari ApiService
      final bool loginSuccess = await apiService.login(
        _usernameController.text,
        _passwordController.text,
      );

      // Guard clause untuk menangani warning 'use_build_context_synchronously'
      if (!mounted) return;

      if (loginSuccess) {
        // Jika berhasil, panggil checkAutoLogin untuk memperbarui state global
        // Ini akan secara reaktif mengubah UI di main.dart
        await Provider.of<AuthNotifier>(context, listen: false).checkAutoLogin();
      } else {
        // Jika gagal, tampilkan pesan error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login gagal. Periksa kembali username dan password Anda.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Guard clause juga diperlukan di sini jika terjadi exception
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Login Orang Tua',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'SMK N 1 Pringsurat',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username / NIS', border: OutlineInputBorder()),
                  validator: (value) => (value == null || value.isEmpty) ? 'Username tidak boleh kosong' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                  validator: (value) => (value == null || value.isEmpty) ? 'Password tidak boleh kosong' : null,
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('LOGIN'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}