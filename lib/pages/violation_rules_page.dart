import 'package:flutter/material.dart';
import 'package:mobile_ortu/services/api_service.dart';

import 'dart:developer';
class ViolationRulesPage extends StatefulWidget {
  const ViolationRulesPage({super.key});

  @override
  State<ViolationRulesPage> createState() => _ViolationRulesPageState();
}

class _ViolationRulesPageState extends State<ViolationRulesPage> {
  final _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _rules = [];
  List<dynamic> _filteredRules = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchRules();
    _searchController.addListener(_filterRules);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterRules);
    _searchController.dispose();
    super.dispose();
  }

  void _filterRules() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredRules = _rules.where((rule) {
        final ruleName = (rule['violation_name'] as String?)?.toLowerCase() ?? '';
        return ruleName.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchRules() async {
    try {
      // Panggil fungsi yang benar untuk mengambil data aturan pelanggaran.
      final response = await _apiService.getViolationRules();

      // Pastikan respons adalah List, jika tidak, coba ambil dari key 'data'
      final List<dynamic> rulesData = (response is Map && response.containsKey('data')) ? response['data'] : response;

      if (mounted) {
        setState(() {
          _rules = rulesData;
          _filteredRules = rulesData;
          _isLoading = false;
        });
      }
    } catch (e) {
      log('Failed to fetch rules: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat data aturan. Silakan coba lagi.';
          _isLoading = false;
          _rules = []; // Kosongkan list jika terjadi error
          _filteredRules = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Aturan & Poin'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, textAlign: TextAlign.center))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Cari Aturan Pelanggaran',
                          hintText: 'Ketik nama pelanggaran...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _filteredRules.isEmpty
                          ? const Center(child: Text('Aturan tidak ditemukan.'))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: _filteredRules.length,
                              itemBuilder: (context, index) {
                                final rule = _filteredRules[index] as Map<String, dynamic>;
                                // Gunakan key dari backend: 'violation_name', 'points', 'category'
                                final ruleName = rule['violation_name'] ?? 'Aturan Tidak Diketahui';
                                final points = rule['points']?.toString() ?? '0';
                                final category = rule['category'] ?? 'Umum';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  elevation: 2,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.orange[100],
                                      child: Text(
                                        points,
                                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(
                                      ruleName,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text('Kategori: $category'),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}