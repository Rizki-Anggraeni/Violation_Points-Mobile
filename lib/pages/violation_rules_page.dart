import 'package:flutter/material.dart';
import 'package:mobile_ortu/services/api_service.dart';
import 'package:provider/provider.dart';

import 'dart:developer';
class ViolationRulesPage extends StatefulWidget {
  const ViolationRulesPage({super.key});

  @override
  State<ViolationRulesPage> createState() => _ViolationRulesPageState();
}

class _ViolationRulesPageState extends State<ViolationRulesPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _rules = [];
  List<dynamic> _filteredRules = [];

  int _currentPage = 1;
  final int _itemsPerPage = 10;

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
      _currentPage = 1; // Reset ke halaman pertama setiap kali ada pencarian baru
    });
  }

  Future<void> _fetchRules() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      // Panggil fungsi yang benar untuk mengambil data aturan pelanggaran.
      final response = await apiService.getViolationRules();

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
    // Logika untuk paginasi
    final int totalItems = _filteredRules.length;
    final int totalPages = (totalItems / _itemsPerPage).ceil();
    final int startIndex = (_currentPage - 1) * _itemsPerPage;
    final int endIndex = (startIndex + _itemsPerPage > totalItems) ? totalItems : startIndex + _itemsPerPage;
    final List<dynamic> paginatedRules = (startIndex < totalItems) 
        ? _filteredRules.sublist(startIndex, endIndex) 
        : [];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Daftar Aturan & Poin'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
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
                      child: paginatedRules.isEmpty
                          ? const Center(child: Text('Aturan tidak ditemukan.'))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: paginatedRules.length,
                              itemBuilder: (context, index) {
                                final rule = paginatedRules[index] as Map<String, dynamic>;
                                // Gunakan key dari backend: 'violation_name', 'points', 'category'
                                final ruleName = rule['violation_name'] ?? 'Aturan Tidak Diketahui';
                                final points = rule['points']?.toString() ?? '0';
                                final category = rule['category'] ?? 'Umum';

                                return Card(
                                  elevation: 0,
                                  color: Colors.white,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey[200]!),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.red.withAlpha(26), // 255 * 0.1
                                      child: Text(
                                        '+$points',
                                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    title: Text(
                                      ruleName,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text('Kategori: $category', style: TextStyle(color: Colors.grey[600])),
                                  ),
                                );
                              },
                            ),
                    ),
                    // Kontrol Paginasi
                    if (totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                              child: const Text('‹ Sebelumnya'),
                            ),
                            Text('Hal $_currentPage dari $totalPages', style: const TextStyle(fontWeight: FontWeight.w500)),
                            TextButton(
                              onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                              child: const Text('Berikutnya ›'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}