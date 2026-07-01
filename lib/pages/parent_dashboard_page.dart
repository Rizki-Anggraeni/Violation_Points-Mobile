import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:developer';
import 'package:dio/dio.dart'; // <-- Tambahkan impor ini
import 'dart:async'; // Import library untuk Timer

import 'package:mobile_ortu/main.dart';
import 'package:mobile_ortu/services/api_service.dart';
import 'package:mobile_ortu/pages/violation_rules_page.dart';

class ParentDashboardPage extends StatefulWidget {
  const ParentDashboardPage({super.key});

  @override
  State<ParentDashboardPage> createState() => _ParentDashboardPageState();
}

class _ParentDashboardPageState extends State<ParentDashboardPage> {
  bool _isLoading = true;
  String? _errorMessage;

  // State baru untuk filter tanggal dan data
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _allViolations = [];
  List<dynamic> _allAttendances = [];
  List<dynamic> _schedules = [];
  List<dynamic> _allStudents = [];

  // State untuk data yang sudah difilter
  List<dynamic> _filteredViolationsToday = [];
  List<dynamic> _filteredRecentViolations = [];
  List<dynamic> _filteredAttendanceToday = [];
  List<dynamic> _filteredScheduleForDay = [];

  Map<String, dynamic>? _selectedStudent;

  // Deklarasi Timer untuk auto-refresh
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Menggunakan addPostFrameCallback untuk memastikan context siap saat memanggil _fetchData
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
      // Inisialisasi timer untuk auto-refresh setiap 10 detik
      _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        // Panggil _fetchData tanpa menampilkan loading indicator
        _fetchData(showLoadingIndicator: false);
      });
    });
  }

  @override
  void dispose() {
    // Batalkan timer saat halaman ditutup untuk mencegah memory leak
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Mengambil semua data dari backend, lalu UI akan memfilternya.
  Future<void> _fetchData({bool showLoadingIndicator = true}) async {
    if (showLoadingIndicator) {
      setState(() => _isLoading = true);
    }
    try {
      // Ambil ApiService sekali saja di awal untuk efisiensi.
      final apiService = Provider.of<ApiService>(context, listen: false);

      // Lakukan empat request API secara bersamaan
      final responses = await Future.wait([
        apiService.getViolations(),
        apiService.getAttendances(),
        apiService.getSchedules(),
        apiService.getStudents(), // Ambil data siswa
      ]);

      final List<dynamic> violationsResponse = responses[0];
      final List<dynamic> attendancesResponse = responses[1];
      final dynamic rawSchedulesResponse = responses[2];
      final dynamic rawStudentsResponse = responses[3];

      // Penyesuaian: Pastikan kita mengambil list dari dalam key 'data' jika ada.
      final List<dynamic> schedulesResponse =
          (rawSchedulesResponse is Map && rawSchedulesResponse.containsKey('data')) ? rawSchedulesResponse['data'] : rawSchedulesResponse;
      final List<dynamic> studentsResponse =
          (rawStudentsResponse is Map && rawStudentsResponse.containsKey('data')) ? rawStudentsResponse['data'] : rawStudentsResponse;

      // Guard clause untuk memastikan widget masih ada
      if (!mounted) return;

      setState(() {
        _allViolations = violationsResponse;
        _allAttendances = attendancesResponse;
        _schedules = schedulesResponse;
        _allStudents = studentsResponse;

        // Jika ada data siswa, pilih siswa pertama sebagai default
        if (_allStudents.isNotEmpty) {
          _selectedStudent = _allStudents.first;
        }
        // Panggil filter awal setelah data didapat
        _updateFilteredData();

        _errorMessage = null;
        if (showLoadingIndicator) {
          _isLoading = false;
        }
      });
    } catch (e) {
      // Jika error BUKAN 401 (karena 401 sudah ditangani interceptor), tampilkan pesan.
      // Jika error adalah DioException dan statusnya bukan 401, atau jenis error lain.
      if (mounted) {
        // Cek apakah error adalah DioException dan bukan 401
        if (e is! DioException || e.response?.statusCode != 401) {
          log('Error fetching dashboard data', error: e);
          setState(() {
            _errorMessage = "Gagal memuat data. Periksa koneksi internet Anda.";
            if (showLoadingIndicator) {
              _isLoading = false;
            }
          });
        }
        // Jika error 401, tidak perlu setState karena akan di-redirect oleh AuthNotifier.
      }
    }
  }

  /// Memperbarui semua data yang difilter berdasarkan state saat ini.
  void _updateFilteredData() {
    if (_selectedStudent == null) return;

    final studentId = _selectedStudent!['_id'];

    // Filter presensi untuk hari ini
    _filteredAttendanceToday = _allAttendances.where((att) {
      if (att['student_id']?['_id'] != studentId) return false;
      try {
        final attDate = DateTime.parse(att['date']);
        return attDate.year == _selectedDate.year &&
            attDate.month == _selectedDate.month &&
            attDate.day == _selectedDate.day;
      } catch (e) {
        return false;
      }
    }).toList();

    // Filter jadwal untuk hari ini
    final String dayName = DateFormat('EEEE', 'id_ID').format(_selectedDate);
    _filteredScheduleForDay = _schedules.where((schedule) {
      return schedule['day'].toString().toLowerCase() == dayName.toLowerCase();
    }).toList();

    // Filter pelanggaran untuk hari ini
    _filteredViolationsToday = _allViolations.where((v) {
      if (v['student_id']?['_id'] != studentId) return false;
      try {
        final vDate = DateTime.parse(v['createdAt']);
        return vDate.year == _selectedDate.year &&
            vDate.month == _selectedDate.month &&
            vDate.day == _selectedDate.day;
      } catch (e) {
        return false;
      }
    }).toList();

    // Filter 5 pelanggaran terakhir
    final studentViolations =
        _allViolations.where((v) => v['student_id']?['_id'] == studentId).toList();
    studentViolations.sort((a, b) {
      final dateA = DateTime.parse(a['createdAt']);
      final dateB = DateTime.parse(b['createdAt']);
      return dateB.compareTo(dateA);
    });
    _filteredRecentViolations = studentViolations.take(5).toList();
  }

  /// Fungsi untuk menampilkan date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // Panggil filter data setelah tanggal berubah
        _updateFilteredData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Menggunakan warna latar belakang yang lebih lembut, senada dengan web
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Dashboard Siswa', style: TextStyle(fontWeight: FontWeight.bold)),
        // AppBar dibuat lebih minimalis
        backgroundColor: Colors.grey[100],
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.gavel),
            tooltip: 'Lihat Aturan',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ViolationRulesPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              // Panggil fungsi logout dari AuthNotifier
              Provider.of<AuthNotifier>(context, listen: false).logout();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      _buildProfileCard(),
                      if (_allStudents.length > 1)
                        _buildStudentSelector(),
                      const SizedBox(height: 20),
                      _buildDatePicker(),
                      const SizedBox(height: 20),
                      _buildAttendanceSection(),
                      const SizedBox(height: 20),
                      _buildScheduleSection(),
                      const SizedBox(height: 20),
                      _buildViolationsSection(),
                      const SizedBox(height: 20),
                      _buildRecentViolationsSection(),
                    ],
                  ),
                ),
      ),
    );
  }

  /// Widget untuk menampilkan kartu profil siswa.
  Widget _buildProfileCard() {
    if (_selectedStudent == null) {
      return const SizedBox.shrink();
    }

    // Ambil data langsung dari objek siswa yang dipilih untuk konsistensi.
    // Pastikan backend mengirimkan 'total_points' di dalam data siswa.
    final studentName = _selectedStudent!['name'] ?? 'Nama Siswa';
    final studentNis = _selectedStudent!['nis']?.toString() ?? '-';
    // Ambil nama kelas dari objek 'class_id' yang di-populate.
    final studentClass = _selectedStudent!['class_id']?['name'] ?? 'Belum ada kelas';
    // Gunakan total poin dari data siswa, bukan dihitung ulang di frontend.
    final totalPoin = _selectedStudent!['total_points']?.toString() ?? '0';

    // Kartu profil dengan gradient dan desain yang lebih menarik
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)], // Blue-700 to Blue-500
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withAlpha(77),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Icon(Icons.person_outline, size: 32, color: Color(0xFF1E3A8A)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NIS: $studentNis | $studentClass',
                      style: TextStyle(color: Colors.blue[100], fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Poin Pelanggaran', style: TextStyle(color: Colors.white, fontSize: 16)),
                Text(totalPoin, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Widget baru untuk memilih siswa jika ada lebih dari satu.
  Widget _buildStudentSelector() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value: _selectedStudent,
          isExpanded: true,
          icon: const Icon(Icons.switch_account_outlined, color: Colors.blue),
          items: _allStudents.map((student) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: student,
              child: Text(
                student['name'] ?? 'Siswa',
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              ),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() {
                _selectedStudent = newValue;
                // Reset tanggal ke hari ini saat ganti siswa untuk konsistensi
                _selectedDate = DateTime.now();
                // Panggil filter data setelah siswa berubah
                _updateFilteredData();
              });
            }
          },
        ),
      ),
    );
  }

  /// Widget baru untuk memilih tanggal.
  Widget _buildDatePicker() {
    return InkWell(
      onTap: () => _selectDate(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, color: Colors.blue, size: 20),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tanggal Laporan', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
            const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  /// Widget baru untuk section presensi.
  Widget _buildAttendanceSection() {
    if (_selectedStudent == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status Presensi',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _filteredAttendanceToday.isEmpty
            ? _buildInfoCard(
                icon: Icons.info_outline,
                text: 'Belum ada data presensi pada tanggal ini.',
                bgColor: Colors.grey[200]!,
                textColor: Colors.black54,
              )
            : _buildAttendanceBadge(_filteredAttendanceToday.first['status']),
      ],
    );
  }

  /// Widget untuk menampilkan badge status presensi.
  Widget _buildAttendanceBadge(String status) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status.toUpperCase()) {
      case 'MASUK':
        bgColor = Colors.green.shade800.withAlpha(26);
        textColor = Colors.green[800]!;
        icon = Icons.check_circle_outline;
        break;
      case 'SAKIT':
        bgColor = Colors.orange.shade800.withAlpha(26);
        textColor = Colors.orange[800]!;
        icon = Icons.sick_outlined;
        break;
      case 'IZIN':
        bgColor = Colors.blue.shade800.withAlpha(26);
        textColor = Colors.blue[800]!;
        icon = Icons.info_outline;
        break;
      case 'ALFA':
      default:
        bgColor = Colors.red.shade800.withAlpha(26);
        textColor = Colors.red[800]!;
        icon = Icons.cancel_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(width: 12),
          Text(
            status.toUpperCase(),
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// Widget baru untuk section jadwal pelajaran.
  Widget _buildScheduleSection() {
    if (_selectedStudent == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jadwal Pelajaran',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _filteredScheduleForDay.isEmpty
            ? _buildInfoCard(
                icon: Icons.calendar_month_outlined,
                text: 'Tidak ada jadwal pelajaran pada hari ini.',
                bgColor: Colors.grey[200]!,
                textColor: Colors.black54,
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredScheduleForDay.length,
                itemBuilder: (context, index) {
                  try {
                    // Pastikan setiap item adalah Map<String, dynamic>
                    final schedule = _filteredScheduleForDay[index] as Map<String, dynamic>;
                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[200]!),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.menu_book_outlined, color: Colors.blue),
                        title: Text(
                          schedule['subject'] ?? 'Mata Pelajaran',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: Text(
                          '${schedule['start_time']} - ${schedule['end_time']}',
                          style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                        ),
                      ),
                    );
                  } catch (e) {
                    log('Error parsing schedule item at index $index', error: e);
                    // Jika satu item gagal di-parsing, tampilkan widget alternatif yang aman
                    return const Card(
                      color: Colors.grey,
                      child: ListTile(
                        title: Text('Data jadwal tidak valid'),
                      ),
                    );
                    }
                },
              ),
      ],
    );
  }

  /// Widget baru untuk section pelanggaran.
  Widget _buildViolationsSection() {
    if (_selectedStudent == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pelanggaran Hari Ini',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _filteredViolationsToday.isEmpty
            ? _buildInfoCard(
                icon: Icons.verified_outlined,
                text: 'Tidak ada catatan pelanggaran pada tanggal ini.',
                bgColor: Colors.green.shade800.withAlpha(26),
                textColor: Colors.green[800]!,
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredViolationsToday.length,
                itemBuilder: (context, index) {
                  final violation = _filteredViolationsToday[index];
                  final date = DateTime.parse(violation['createdAt'] as String);
                  final formattedDate = DateFormat('HH:mm', 'id_ID').format(date);

                  return Card(
                    elevation: 0,
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.shade800.withAlpha(26),
                        child: Text(
                          '+${violation['rule_id']?['points'] ?? 0}',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      title: Text(violation['rule_id']?['violation_name'] ?? 'Nama Pelanggaran Tidak Diketahui'),
                      subtitle: Text('Dicatat pukul $formattedDate'),
                    ),
                  );
                },
              ),
      ],
    );
  }

  /// Widget untuk menampilkan 5 pelanggaran terakhir.
  Widget _buildRecentViolationsSection() {
    if (_selectedStudent == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '5 Pelanggaran Terakhir',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _filteredRecentViolations.isEmpty
            ? _buildInfoCard(
                icon: Icons.history_edu_outlined,
                text: 'Tidak ada riwayat pelanggaran yang tercatat.',
                bgColor: Colors.grey[200]!,
                textColor: Colors.black54,
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredRecentViolations.length,
                itemBuilder: (context, index) {
                  final violation = _filteredRecentViolations[index];
                  // Format tanggal yang lebih lengkap
                  final date = DateTime.parse(violation['createdAt'] as String);
                  final formattedDate = DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(date);

                  return Card(
                    elevation: 0,
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.shade800.withAlpha(26),
                        child: Text(
                          '+${violation['rule_id']?['points'] ?? 0}',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      title: Text(violation['rule_id']?['violation_name'] ?? 'Nama Pelanggaran Tidak Diketahui'),
                      subtitle: Text('Dicatat pada $formattedDate'),
                    ),
                  );
                },
              ),
      ],
    );
  }

  /// Widget helper untuk menampilkan kartu informasi (misal: 'Tidak ada data').
  Widget _buildInfoCard({required IconData icon, required String text, required Color bgColor, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}