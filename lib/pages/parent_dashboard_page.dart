import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:developer';

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
  Map<String, dynamic>? _selectedStudent;

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
                      if (_allStudents.length > 1)
                        _buildStudentSelector(), // Tampilkan jika siswa lebih dari 1
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
                      studentName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                      'NIS: $studentNis | Kelas: $studentClass',
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
                      totalPoin,
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

  /// Widget baru untuk memilih siswa jika ada lebih dari satu.
  Widget _buildStudentSelector() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value: _selectedStudent,
          isExpanded: true,
          icon: const Icon(Icons.switch_account_outlined),
          items: _allStudents.map((student) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: student,
              child: Text(
                student['name'] ?? 'Siswa',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() {
                _selectedStudent = newValue;
                // Reset tanggal ke hari ini saat ganti siswa untuk konsistensi
                _selectedDate = DateTime.now();
              });
            }
          },
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
    if (_selectedStudent == null) return const SizedBox.shrink();

    final attendanceToday = _allAttendances.where((att) {
      if (att['student_id']?['_id'] != _selectedStudent!['_id']) return false;

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
    if (_selectedStudent == null) return const SizedBox.shrink();

    // Ambil nama hari dari tanggal yang dipilih (misal: 'Senin')
    final String dayName = DateFormat('EEEE', 'id_ID').format(_selectedDate);

    // Asumsi: Jadwal tidak spesifik per siswa, tetapi per kelas.
    // Jika spesifik per siswa, tambahkan filter `schedule['student_id'] == _selectedStudent!['id']`
    // Filter jadwal berdasarkan nama hari
    final scheduleForDay = _schedules.where((schedule) {
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
        scheduleForDay.isEmpty
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
                itemCount: scheduleForDay.length,
                itemBuilder: (context, index) {
                  try {
                    // Pastikan setiap item adalah Map<String, dynamic>
                    final schedule = scheduleForDay[index] as Map<String, dynamic>;
                    return Card(
                      elevation: 1,
                      shadowColor: Colors.black12,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        title: Text(
                          schedule['subject'] ?? 'Mata Pelajaran',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${schedule['start_time']} - ${schedule['end_time']}',
                          style: TextStyle(color: Colors.grey[600]),
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

    final violationsToday = _allViolations.where((v) {
      if (v['student_id']?['_id'] != _selectedStudent!['_id']) return false;

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
}