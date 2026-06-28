import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:developer';

import 'package:mobile_ortu/main.dart';
import 'package:mobile_ortu/services/api_service.dart';

class ParentDashboardPage extends StatefulWidget {
  const ParentDashboardPage({super.key});

  @override
  State<ParentDashboardPage> createState() => _ParentDashboardPageState();
}

class _ParentDashboardPageState extends State<ParentDashboardPage> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _studentProfile;

  // State baru untuk filter tanggal dan data
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _allViolations = [];
  List<dynamic> _allAttendances = [];
  List<dynamic> _schedules = [];

  @override
  void initState() {
    super.initState();
    // Menggunakan addPostFrameCallback untuk memastikan context siap saat memanggil _fetchData
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchData());
  }

  /// Mengambil semua data dari backend, lalu UI akan memfilternya.
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {      
      // Lakukan tiga request API secara bersamaan
      final responses = await Future.wait([
        // Ambil ApiService dari Provider untuk setiap request
        Provider.of<ApiService>(context, listen: false).getViolations(),
        Provider.of<ApiService>(context, listen: false).getAttendances(),
        Provider.of<ApiService>(context, listen: false).getSchedules(),
      ]);

      final List<dynamic> violationsResponse = responses[0];
      final List<dynamic> attendancesResponse = responses[1];
      final dynamic rawSchedulesResponse = responses[2];

      // Penyesuaian: Pastikan kita mengambil list dari dalam key 'data' jika ada.
      final List<dynamic> schedulesResponse =
          (rawSchedulesResponse is Map && rawSchedulesResponse.containsKey('data')) ? rawSchedulesResponse['data'] : rawSchedulesResponse;

      // Guard clause untuk memastikan widget masih ada
      if (!mounted) return;

      // Hitung total poin secara dinamis dari semua pelanggaran
      int totalPoinDinamis = violationsResponse.fold(0, (sum, violation) {
        final poin = int.tryParse(violation['points_issued'].toString()) ?? 0;
        return sum + poin;
      });

      // Buat data profil dari data pertama yang tersedia
      String studentName = 'Ahmad Budi Santoso';
      String studentNis = '23.4567';
      String studentClass = 'XI PPLG A';
      if (violationsResponse.isNotEmpty && violationsResponse.first['student'] != null) {
        studentName = violationsResponse.first['student']['name'] ?? studentName;
        studentNis = violationsResponse.first['student']['nis'] ?? studentNis;
        studentClass = violationsResponse.first['student']['class']?['name'] ?? studentClass;
      }

      setState(() {
        _allViolations = violationsResponse;
        _allAttendances = attendancesResponse;
        _schedules = schedulesResponse;
        _studentProfile = {
          'name': studentName,
          'nis': studentNis,
          'class': studentClass,
          'total_points': totalPoinDinamis,
        };
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      log('Error fetching dashboard data', error: e);
      if (mounted) {
        setState(() {
          _errorMessage = "Gagal memuat data: ${e.toString()}";
          _isLoading = false;
        });
      }
    }
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
        // Tidak perlu panggil _fetchData() lagi, UI akan re-render dengan tanggal baru
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Orang Tua'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
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
      body: _isLoading
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
                      _buildProfileCard(), // Menampilkan profil siswa
                      const SizedBox(height: 24),
                      _buildDatePicker(), // Widget baru untuk memilih tanggal
                      const SizedBox(height: 24),
                      _buildAttendanceSection(), // Section baru untuk presensi
                      const SizedBox(height: 24),
                      _buildScheduleSection(), // Section baru untuk jadwal pelajaran
                      const SizedBox(height: 24),
                      _buildViolationsSection(), // Section untuk pelanggaran
                    ],
                  ),
                ),
    );
  }

  /// Widget untuk menampilkan kartu profil siswa.
  Widget _buildProfileCard() {
    if (_studentProfile == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  child: Icon(Icons.person, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _studentProfile!['name'] ?? 'Nama Siswa',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'NIS: ${_studentProfile!['nis'] ?? '-'} | Kelas: ${_studentProfile!['class'] ?? '-'}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      (_studentProfile!['total_points'] ?? 0).toString(),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const Text('Total Poin Pelanggaran'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Widget baru untuk memilih tanggal.
  Widget _buildDatePicker() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today),
        title: const Text('Pilih Tanggal'),
        subtitle: Text(DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_selectedDate)),
        trailing: const Icon(Icons.arrow_drop_down),
        onTap: () => _selectDate(context),
      ),
    );
  }

  /// Widget baru untuk section presensi.
  Widget _buildAttendanceSection() {
    final attendanceToday = _allAttendances.where((att) {
      final attDate = DateTime.parse(att['date']);
      return attDate.year == _selectedDate.year &&
          attDate.month == _selectedDate.month &&
          attDate.day == _selectedDate.day;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status Presensi',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        attendanceToday.isEmpty
            ? const Text('Belum ada data presensi pada tanggal ini.')
            : _buildAttendanceBadge(attendanceToday.first['status']),
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
        bgColor = Colors.green.withAlpha(26);
        textColor = Colors.green[800]!;
        icon = Icons.check_circle_outline;
        break;
      case 'SAKIT':
        bgColor = Colors.orange.withAlpha(26);
        textColor = Colors.orange[800]!;
        icon = Icons.sick_outlined;
        break;
      case 'IZIN':
        bgColor = Colors.blue.withAlpha(26);
        textColor = Colors.blue[800]!;
        icon = Icons.info_outline;
        break;
      case 'ALFA':
      default:
        bgColor = Colors.red.withAlpha(26);
        textColor = Colors.red[800]!;
        icon = Icons.cancel_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 8),
          Text(
            status.toUpperCase(),
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Widget baru untuk section jadwal pelajaran.
  Widget _buildScheduleSection() {
    // Ambil nama hari dari tanggal yang dipilih (misal: 'Senin')
    final String dayName = DateFormat('EEEE', 'id_ID').format(_selectedDate);

    // Filter jadwal berdasarkan nama hari
    final scheduleToday = _schedules.where((schedule) {
      return schedule['day'].toString().toLowerCase() == dayName.toLowerCase();
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jadwal Pelajaran Hari Ini',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        scheduleToday.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'Tidak ada jadwal pelajaran pada hari ini.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: scheduleToday.length,
                itemBuilder: (context, index) {
                  try {
                    // Pastikan setiap item adalah Map<String, dynamic>
                    final schedule = scheduleToday[index] as Map<String, dynamic>;
                    return Card(
                      elevation: 1,
                      shadowColor: Colors.black12,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        title: Text(
                          schedule['subject']?['name'] ?? 'Mata Pelajaran',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${schedule['start_time']} - ${schedule['end_time']}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        trailing: Text(
                          schedule['teacher']?['name'] ?? 'Guru Pengampu',
                          style: const TextStyle(fontSize: 12),
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
    final violationsToday = _allViolations.where((v) {
      final vDate = DateTime.parse(v['createdAt']);
      return vDate.year == _selectedDate.year &&
          vDate.month == _selectedDate.month &&
          vDate.day == _selectedDate.day;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Riwayat Pelanggaran Hari Ini',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        violationsToday.isEmpty
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Tidak ada catatan pelanggaran pada tanggal ini.',
                    style: TextStyle(color: Colors.green[800]),
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: violationsToday.length,
                itemBuilder: (context, index) {
                  final violation = violationsToday[index];
                  final date = DateTime.parse(violation['createdAt']);
                  final formattedDate = DateFormat('HH:mm', 'id_ID').format(date);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.red[100],
                        child: Text(
                          '+${violation['points_issued']}',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      title: Text(violation['violation_rule']?['name'] ?? 'Nama Pelanggaran Tidak Diketahui'),
                      subtitle: Text('Kejadian pukul $formattedDate'),
                    ),
                  );
                },
              ),
      ],
    );
  }
}