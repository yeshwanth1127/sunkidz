import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../../../core/api/current_user_provider.dart';
import '../../../shared/widgets/admin_drawer.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../data/dashboard_provider.dart';

// ─── Palette ────────────────────────────────────────────────────────────────
const _kBg     = Color(0xFFFFF4DF);
const _kBlue   = Color(0xFFA6CFFF);
const _kGreen  = Color(0xFF9DE0C2);

// ─── Decorative shape colours ─────────────────────────────────────────────
const _kShapes = [
  Color(0xFFFFBDE0), Color(0xFFB3EDFF), Color(0xFFB3FFD9),
  Color(0xFFDDAAFF), Color(0xFFFFD680), Color(0xFFA6E3FF),
];

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

final _scaffoldKey = GlobalKey<ScaffoldState>();

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _bgController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        context.go('/admin');
        break;
      case 1:
        context.push('/admissions');
        break;
      case 2:
        context.push('/students');
        break;
      case 3:
        _scaffoldKey.currentState?.openDrawer();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currentUserProvider);
    final dashboardAsync = ref.watch(dashboardDataProvider);

    final data          = dashboardAsync.valueOrNull;
    final newEnq        = data?.newEnquiries ?? 0;
    final converted     = data?.convertedEnquiries ?? 0;
    final rejected      = data?.rejectedEnquiries ?? 0;
    final admThisMonth  = data?.admissionsThisMonth.length ?? 0;
    final recentEnquiries = data?.recentEnquiries ?? [];

    final total = (newEnq + converted + rejected).toDouble();
    final conversionRate = total == 0
        ? '0.0%'
        : '${(converted / (newEnq + converted) * 100).toStringAsFixed(1)}%';

    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: const AdminDrawer(),
      extendBody: true,
      bottomNavigationBar: _buildFloatingNavBar(context),
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(const Color(0xFFFFF4DF), const Color(0xFFFFF0F5), _bgController.value)!,
                  Color.lerp(const Color(0xFFFFF4DF), const Color(0xFFE8F4FF), _bgController.value)!,
                ],
              ),
            ),
            child: child,
          );
        },
        child: Stack(
          children: [
            // ── Scattered decorative shapes ──────────────────────────────────
          ..._buildScatteredShapes(),

          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(dashboardDataProvider);
                      // Adding a small delay to allow the loading animation to complete visually
                      await Future.delayed(const Duration(milliseconds: 500));
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),

                        // ── "Good morning" & Top Operations ───────────────
                        const Text(
                          'Good morning, Admin',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.send_rounded,
                                label: 'Send Message',
                                color: const Color(0xFFBBE5FE),
                                onTap: () => context.push('/admin/send-message'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.notifications_active_rounded,
                                label: 'View Messages',
                                color: const Color(0xFFFFDEB2),
                                onTap: () => context.push('/admin/notifications'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Top Stats Grid
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.7,
                          children: [
                            _StatCard(
                              title: 'BRANCHES',
                              value: '${data?.branchesCount ?? 0}',
                              icon: Icons.apartment_rounded,
                              color: const Color(0xFF9FD7FA),
                              onTap: () => context.push('/branches'),
                            ),
                            _StatCard(
                              title: 'STUDENTS',
                              value: '${data?.studentsCount ?? 0}',
                              icon: Icons.face_retouching_natural_rounded,
                              color: const Color(0xFFFFC56F),
                              onTap: () => context.push('/students'),
                            ),
                            _StatCard(
                              title: 'STAFF',
                              value: '${data?.staffCount ?? 0}',
                              icon: Icons.groups_rounded,
                              color: const Color(0xFFA5E3BA),
                              onTap: () => context.push('/staff'),
                            ),
                            _StatCard(
                              title: 'FEES PENDING',
                              value: currencyFmt.format(data?.feesPending ?? 0),
                              icon: Icons.wallet_rounded,
                              color: const Color(0xFFFFBCCB),
                              suberText: 'Collected ${currencyFmt.format(data?.feesCollected ?? 0)} / Due ${currencyFmt.format(data?.feesTotalDue ?? 0)}',
                              onTap: () => context.push('/admin/fees'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // ── Quick Metrics ─────────────────────────────────
                        _sectionTitle('Quick Metrics'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                color: _kBlue,
                                icon: Icons.mail_outline_rounded,
                                label: 'New Enquiries',
                                value: newEnq.toString(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MetricCard(
                                color: _kGreen,
                                icon: Icons.trending_up_rounded,
                                label: 'Conversion Rate',
                                value: conversionRate,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── Enquiry Status Overview ───────────────────────
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(160),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withAlpha(200), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(10),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Enquiry Status Overview',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87),
                              ),
                              const SizedBox(height: 20),
                              _WavyProgressBar(
                                label: 'New Enquiries',
                                value: newEnq,
                                total: total == 0 ? 1 : total,
                                color: const Color(0xFF4FA5F5),
                              ),
                              const SizedBox(height: 20),
                              _WavyProgressBar(
                                label: 'Converted',
                                value: converted,
                                total: total == 0 ? 1 : total,
                                color: const Color(0xFF63D38D),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: _WavyProgressBar(
                                      label: 'Rejected',
                                      value: rejected,
                                      total: total == 0 ? 1 : total,
                                      color: const Color(0xFFF1615E),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Container(
                                    width: 130,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFFE5BCFF),
                                          Color(0xFFB57BFB),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFB57BFB).withAlpha(128),
                                          blurRadius: 16,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Admissions\nThis Month',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black87, height: 1.2),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Text(
                                              admThisMonth.toString(),
                                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black),
                                            ),
                                            const Spacer(),
                                            const Icon(Icons.trending_up_rounded, size: 28, color: Colors.deepPurple),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                        // ── Recent Enquiries ──────────────────────────────
                        _sectionTitle('Recent Enquiries'),
                        const SizedBox(height: 12),
                        if (recentEnquiries.isEmpty)
                          Center(
                            child: Text('No recent enquiries',
                                style: TextStyle(color: Colors.grey[500])),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 16,
                              childAspectRatio: 2.2,
                            ),
                            itemCount: recentEnquiries.length,
                            itemBuilder: (context, index) {
                              final enq = recentEnquiries[index];
                              final status = (enq['status'] ?? 'new')
                                  .toString()
                                  .toLowerCase();
                              return _EnquiryCard(
                                name: enq['child_name'] ?? enq['full_name'] ?? 'Unknown',
                                status: status,
                                index: index,
                              );
                            },
                          ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ── Scattered decorative shapes ──────────────────────────────────────────
  List<Widget> _buildScatteredShapes() {
    final rng = Random(42);
    final size = MediaQuery.of(context).size;
    return List.generate(14, (i) {
      final color = _kShapes[i % _kShapes.length];
      final top    = rng.nextDouble() * size.height;
      final left   = rng.nextDouble() * size.width;
      final shapeSize = 8.0 + rng.nextDouble() * 14;
      final isCircle = i % 3 != 0;
      final isStar   = i % 5 == 0;
      
      final dx = (rng.nextDouble() - 0.5) * 60;
      final dy = (rng.nextDouble() - 0.5) * 60;

      return AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          final offset = Curves.easeInOutSine.transform(_bgController.value);
          return Positioned(
            top: top + (dy * offset),
            left: left + (dx * offset),
            child: child!,
          );
        },
        child: isStar
            ? _StarShape(color: color, size: shapeSize)
            : Container(
                width: shapeSize,
                height: shapeSize,
                decoration: BoxDecoration(
                  color: color,
                  shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: isCircle
                      ? null
                      : BorderRadius.circular(shapeSize * 0.3),
                ),
              ),
      );
    });
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Menu button
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu_rounded, size: 28, color: Colors.black87),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
          const Spacer(),
          // Central Logo
          Image.asset(
            'assets/images/new_logo.png',
            height: 38,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          // Right section
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.orange[200],
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              const NotificationBell(notificationsRoute: '/admin/notifications'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNavBar(BuildContext context) {
    const items = [
      _NavItem(icon: Icons.home_rounded,         label: 'Home'),
      _NavItem(icon: Icons.assignment_add,        label: 'Admissions'),
      _NavItem(icon: Icons.people_alt_rounded,    label: 'Students'),
      _NavItem(icon: Icons.more_horiz_rounded,    label: 'More'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(31),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final selected = _selectedIndex == i;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onItemTapped(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? _kBlue.withAlpha(38) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      items[i].icon,
                      size: 24,
                      color: selected ? _kBlue : Colors.grey[400],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i].label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                        color: selected ? _kBlue : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
      );
}

// ─── Star Shape ───────────────────────────────────────────────────────────────
class _StarShape extends StatelessWidget {
  final Color color;
  final double size;
  const _StarShape({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StarPainter(color),
      size: Size(size, size),
    );
  }
}

class _StarPainter extends CustomPainter {
  final Color color;
  _StarPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path  = Path();
    final cx    = size.width / 2;
    final cy    = size.height / 2;
    const points = 4;
    final outerR = size.width / 2;
    final innerR = size.width / 4;
    for (int i = 0; i < points * 2; i++) {
      final angle = (i * pi / points) - pi / 2;
      final r = i.isEven ? outerR : innerR;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.color != color;
}

// ─── Metric Card ─────────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final Color  color;
  final IconData icon;
  final String label;
  final String value;
  const _MetricCard({
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: color.withAlpha(210),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withAlpha(180), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(128),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.white.withAlpha(150),
                blurRadius: 4,
                offset: const Offset(-2, -2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 36, color: Colors.black87),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black87),
            maxLines: 2,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black),
          ),
        ],
      ),
        ),
      ),
    );
  }
}

// ─── Wavy Progress Bar ────────────────────────────────────────────────────────
class _WavyProgressBar extends StatefulWidget {
  final String label;
  final int value;
  final double total;
  final Color color;

  const _WavyProgressBar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  State<_WavyProgressBar> createState() => _WavyProgressBarState();
}

class _WavyProgressBarState extends State<_WavyProgressBar> with TickerProviderStateMixin {
  late AnimationController _spawnAnim;
  late AnimationController _waveAnim;

  @override
  void initState() {
    super.initState();
    _spawnAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();
    _waveAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
  }

  @override
  void dispose() {
    _spawnAnim.dispose();
    _waveAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.total == 0) return const SizedBox();
    final progress = widget.value / widget.total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: AnimatedBuilder(
                animation: Listenable.merge([_spawnAnim, _waveAnim]),
                builder: (context, child) {
                  final currentProgress = progress * CurvedAnimation(parent: _spawnAnim, curve: Curves.easeOut).value;
                  return Container(
                    height: 22,
                    decoration: BoxDecoration(
                      color: widget.color.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CustomPaint(
                      painter: _WavePainter(
                        progress: currentProgress,
                        wavePhase: _waveAnim.value,
                        baseColor: widget.color,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 24,
              child: Text(
                widget.value.toString(),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final double wavePhase;
  final Color baseColor;

  _WavePainter({required this.progress, required this.wavePhase, required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final fillWidth = size.width * progress;
    final basePaint = Paint()..color = baseColor..style = PaintingStyle.fill;
    
    final baseRect = RRect.fromLTRBAndCorners(
      0, 0, fillWidth, size.height,
      topLeft: const Radius.circular(12),
      bottomLeft: const Radius.circular(12),
      topRight: progress >= 0.99 ? const Radius.circular(12) : const Radius.circular(12),
      bottomRight: progress >= 0.99 ? const Radius.circular(12) : const Radius.circular(12),
    );
    canvas.drawRRect(baseRect, basePaint);

    final wavePaint = Paint()
      ..color = Colors.white.withAlpha(50)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);

    const waveCount = 2.0; 
    for (double x = 0; x <= fillWidth; x++) {
      final nx = x / size.width;
      final y = size.height / 2 + math.sin((nx * math.pi * 2 * waveCount) + (wavePhase * math.pi * 2)) * (size.height / 3);
      path.lineTo(x, y);
    }
    path.lineTo(fillWidth, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.save();
    canvas.clipRRect(baseRect);
    canvas.drawPath(path, wavePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.wavePhase != wavePhase;
  }
}

// ─── Enquiry Card ─────────────────────────────────────────────────────────────
class _EnquiryCard extends StatelessWidget {
  final String name;
  final String status;
  final int    index;
  const _EnquiryCard({
    required this.name,
    required this.status,
    required this.index,
  });

  static const _avatarColors = [
    Color(0xFFFFDAC1), // Soft peach
    Color(0xFFFFF1C1), // Soft yellow
    Color(0xFFC1EEFF), // Soft light blue
    Color(0xFFC1D4FF), // Soft deeper blue
    Color(0xFFFFC1E3), // Soft pink
  ];

  static const _avatarEmojis = ['🐻', '☀️', '☁️', '🚀', '⭐'];

  Color  _avatarColor()  => _avatarColors[index % _avatarColors.length];
  String _avatarEmoji()  => _avatarEmojis[index % _avatarEmojis.length];

  Color get _badgeBgColor {
    switch (status) {
      case 'converted': return const Color(0xFFB4F1D7);
      case 'rejected':  return const Color(0xFFFFC6C6);
      default:          return const Color(0xFFCDEFFD); // new/pending
    }
  }

  Color get _badgeTextColor {
    switch (status) {
      case 'converted': return const Color(0xFF33A576);
      case 'rejected':  return const Color(0xFFE55858);
      default:          return const Color(0xFF5BAEF1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: _avatarColor(),
          child: Text(_avatarEmoji(), style: const TextStyle(fontSize: 22)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _badgeBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Nav Item ─────────────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String   label;
  const _NavItem({required this.icon, required this.label});
}

// ─── Actions & Stats ──────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(128),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: Colors.black87),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black87)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? suberText;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.suberText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: color.withAlpha(210),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(180), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(100),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Stack(
              children: [
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(80),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 22, color: Colors.black54),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87),
                    ),
                    if (suberText != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        suberText!,
                        style: const TextStyle(fontSize: 7, color: Colors.black54, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }
}
