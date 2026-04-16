import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  final _students = [
    _StudentAtt(name: 'Liam Anderson', rollNo: '01', status: 'present', imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuA_3MzW44bH_lqPTieGXf1BY83MsxcyXMrlKjX7E1lbQIiS28d9uZR4Y-9e36OXbmGaJd4R_7q6ab8bKH2RnjJdrMpPXPifeKV6fQwZ48DMDdga9v4HxNvCyl7p73xbXzjx0HYAAt6ELgfTb2d7ZC-ooE_M1DzvbRFYmTWSjDtILHWF-V_i6ha2y9iFEZ6INYKZ5qf94eNjWX88u91UsvG054j_iHzvUyzwGdvOc8uYrf9put67MK4yeB68mT-e4pVCf1IZ7_Zq4aU'),
    _StudentAtt(name: 'Mia Thompson', rollNo: '02', status: 'absent', imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDw1LAAT15OUrBWQMC3WjEgE01iFahDqcvtCwMt76nEuIweYUUseRG-9zsXOtEb0V4q7g8GRIUCvrl-OXkU-JPw7AtdjhJTexGlrgceqCwUowiR9QExu6FOtVXpj6PGfIRAMHLZ4sQANl4xYbPbYAxSyvFh9O5N9Rxt2KF4UyP2lncHXoMaBtv-5HN_uUMg9gk-I6NypSZmzRTSrGezm9W1xuYegS8XKpoE9Wc1UCJszuKO7tpkD_2EWBy8ico5mNE3ErrR2dup0LE'),
    _StudentAtt(name: 'Noah Williams', rollNo: '03', status: 'leave', imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCeHBDFwYwWUWdB0s0vfbqcRq6Mjt7QY2Zdlaw3QUycN_hFlJrulW3QC0vTRx0GN7enH0uEEnKzU8EJuyvdb4JFgkvnJzriNCnYtUPda81UcNjip7YAJTO4za88VfV5V_tB_eaG3fnhoqHFBTlG7vaK6ficW4GpSu-hr_cKpdQy1IKET_Ae5QsAwaDhQoxjecjk74_AKdPxBcRSwcjgB88VM1a830kB0ZeHFl66KnD7D_dL_JXF7_MLbGqQyGqYPYmHgxfmr2FNI6E'),
    _StudentAtt(name: 'Emma Sophia', rollNo: '04', status: 'present', imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBV7psrkQROj8bzrKAOcaSuRjHOZacM8r1F9m-Tp0TVpFeccjZep1KZZXDJlhO79zpM4Rpv_FgrK78rN3hmNp3-h-s7taombsyi_3tvjortA9hzWN8DNsAaoAsDRReHcsBvvGoUVlV7us7we58RHtU-9XCKCRt3GHfr8wMXUVnC1jo41pCFFI9tQAZ0p-OK3m-q6R-Lq3axEDWO0NVGEYfIpXAHusLSdTHZrzx8QOJy-3XZ9q8jdmA61mwqnv5rGAS6dzaQRdB5zTo'),
    _StudentAtt(name: 'Ethan James (On Leave)', rollNo: '05', status: 'leave', imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCEfZXwEpdQtbyNqG2FrVQMan4MF3G6TQc_z7HpUClxkjZYay9dOH9ziHh5fz3zi13QFgNZVzwktFIRI1FrfVWt10Y-9dKZb3R4IPQMmz-1y3BX_mMPfBDRJDqAXguD0a0q0ijFXoVF6DLEXVXwMdU8loRXQ6-Y7PIlyHLZdlnrEvHrpxHnm97mVWyx5zZqSYuyTlSiER9QSrVJlGGDxqqIz5DpUWCGih0_0c93ly22ERFOaWdvjIuLl2D4p8QXqXSpZRmsJoutByE'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.child_care, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Attendance', style: Theme.of(context).textTheme.titleMedium),
                Text('Preschool LMS • Branch A', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: Icon(Icons.notifications_outlined), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CLASS & SECTION', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: 'Kindergarten - A',
                          decoration: InputDecoration(
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: ['Kindergarten - A', 'Kindergarten - B', 'Nursery - Peach', 'Nursery - Berry'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (_) {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DATE', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Text('Oct 12'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _SummaryChip(label: 'Total: 24', color: AppColors.primary),
                    const SizedBox(width: 8),
                    _SummaryChip(label: 'Present: 21', color: Colors.green),
                    const SizedBox(width: 8),
                    _SummaryChip(label: 'Absent: 2', color: Colors.red),
                    const SizedBox(width: 8),
                    _SummaryChip(label: 'Leave: 1', color: Colors.amber),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.groups, size: 16),
                  const SizedBox(width: 8),
                  Text('Student List', style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ..._students.map((s) => _StudentAttendanceCard(
                  student: s,
                  onStatusChanged: (status) {
                    setState(() => s.status = status);
                  },
                )),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.check_circle),
                  label: const Text('Submit Attendance'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
            Center(child: Text('Last updated 5 mins ago by Ms. Sarah', style: TextStyle(fontSize: 10, color: Colors.grey))),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _StudentAtt {
  final String name;
  final String rollNo;
  String status;
  final String imageUrl;

  _StudentAtt({required this.name, required this.rollNo, required this.status, required this.imageUrl});
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SummaryChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (color != AppColors.primary) Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          if (color != AppColors.primary) const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _StudentAttendanceCard extends StatelessWidget {
  final _StudentAtt student;
  final ValueChanged<String> onStatusChanged;

  const _StudentAttendanceCard({required this.student, required this.onStatusChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            backgroundImage: NetworkImage(student.imageUrl),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: student.status == 'leave' ? Colors.grey : null)),
                Text('Roll #${student.rollNo}', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                _StatusBtn(label: 'P', status: 'present', current: student.status, onTap: () => onStatusChanged('present')),
                _StatusBtn(label: 'A', status: 'absent', current: student.status, onTap: () => onStatusChanged('absent')),
                _StatusBtn(label: 'L', status: 'leave', current: student.status, onTap: () => onStatusChanged('leave')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBtn extends StatelessWidget {
  final String label;
  final String status;
  final String current;
  final VoidCallback onTap;

  const _StatusBtn({required this.label, required this.status, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = current == status;
    Color bg = Colors.transparent;
    Color fg = Colors.grey;
    if (status == 'present') {
      if (isSelected) {
        bg = Colors.green;
        fg = Colors.white;
      }
    } else if (status == 'absent') {
      if (isSelected) {
        bg = Colors.red;
        fg = Colors.white;
      }
    } else if (status == 'leave') {
      if (isSelected) {
        bg = Colors.amber;
        fg = Colors.white;
      }
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
      ),
    );
  }
}
