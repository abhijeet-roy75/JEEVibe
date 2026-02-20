import 'package:flutter/material.dart';

class HomeScreenTest extends StatelessWidget {
  const HomeScreenTest({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Clean white background
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;

          return CustomScrollView(
            slivers: [
              // App Bar - Responsive
              SliverAppBar(
                floating: true,
                backgroundColor: Colors.white,
                elevation: 0,
                title: Center(
                  child: Container(
                    constraints: isDesktop ? const BoxConstraints(maxWidth: 1200) : null,
                    child: Row(
                      children: [
                        Container(
                          width: isDesktop ? 48 : 40,
                          height: isDesktop ? 48 : 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9333EA), Color(0xFFA855F7)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'J',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isDesktop ? 24 : 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: isDesktop ? 16 : 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back!',
                                style: TextStyle(
                                  fontSize: isDesktop ? 15 : 14,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              Text(
                                'JEE Aspirant',
                                style: TextStyle(
                                  fontSize: isDesktop ? 18 : 16,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Pro badge
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 16 : 12,
                            vertical: isDesktop ? 8 : 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9333EA), Color(0xFFA855F7)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'PRO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isDesktop ? 13 : 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Content - Responsive Layout
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 48 : 16,
                  vertical: isDesktop ? 32 : 16,
                ),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: Container(
                      constraints: isDesktop ? const BoxConstraints(maxWidth: 1200) : null,
                      child: isDesktop
                          ? _buildDesktopLayout()
                          : _buildMobileLayout(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Mobile Layout - Single Column (Original)
  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildPriyaCard(isDesktop: false),
        const SizedBox(height: 16),
        _buildDailyQuizCard(isDesktop: false),
        const SizedBox(height: 16),
        _buildFocusAreasCard(isDesktop: false),
        const SizedBox(height: 16),
        _buildMockTestCard(isDesktop: false),
        const SizedBox(height: 16),
        _buildSnapSolveCard(isDesktop: false),
        const SizedBox(height: 16),
        _buildStatsCard(isDesktop: false),
        const SizedBox(height: 80),
      ],
    );
  }

  // Desktop Layout - Two Column Grid
  Widget _buildDesktopLayout() {
    return Column(
      children: [
        // Priya card - Full width on desktop too (important message)
        _buildPriyaCard(isDesktop: true),
        const SizedBox(height: 24),

        // Two-column grid for main cards
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column
            Expanded(
              child: Column(
                children: [
                  _buildDailyQuizCard(isDesktop: true),
                  const SizedBox(height: 24),
                  _buildMockTestCard(isDesktop: true),
                  const SizedBox(height: 24),
                  _buildStatsCard(isDesktop: true),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Right Column
            Expanded(
              child: Column(
                children: [
                  _buildFocusAreasCard(isDesktop: true),
                  const SizedBox(height: 24),
                  _buildSnapSolveCard(isDesktop: true),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildPriyaCard({required bool isDesktop}) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF3E8FF), Color(0xFFFCE7F3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Priya Avatar
          Container(
            width: isDesktop ? 60 : 50,
            height: isDesktop ? 60 : 50,
            decoration: BoxDecoration(
              color: const Color(0xFF9333EA),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(Icons.person, color: Colors.white, size: isDesktop ? 32 : 28),
          ),
          SizedBox(width: isDesktop ? 20 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Priya Ma\'am ✨',
                  style: TextStyle(
                    fontSize: isDesktop ? 17 : 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: isDesktop ? 6 : 4),
                Text(
                  'Great work on yesterday\'s quiz! Ready to tackle today\'s adaptive challenge? 💪',
                  style: TextStyle(
                    fontSize: isDesktop ? 15 : 14,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyQuizCard({required bool isDesktop}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(isDesktop ? 24 : 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9333EA), Color(0xFFA855F7)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isDesktop ? 20 : 16),
                topRight: Radius.circular(isDesktop ? 20 : 16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.quiz, color: Colors.white, size: isDesktop ? 28 : 24),
                SizedBox(width: isDesktop ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Adaptive Quiz',
                        style: TextStyle(
                          fontSize: isDesktop ? 20 : 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: isDesktop ? 6 : 4),
                      Text(
                        'IRT-based personalized learning',
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(isDesktop ? 24 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Details chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChip('✏️ 10 questions', isDesktop: isDesktop),
                    _buildChip('⏱️ ~15 min', isDesktop: isDesktop),
                    _buildChip('📚 Mixed subjects', isDesktop: isDesktop),
                  ],
                ),
                SizedBox(height: isDesktop ? 20 : 16),

                // CTA Button
                SizedBox(
                  width: double.infinity,
                  height: isDesktop ? 52 : 48,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9333EA),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Start Today\'s Quiz',
                      style: TextStyle(
                        fontSize: isDesktop ? 17 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusAreasCard({required bool isDesktop}) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.track_changes, color: const Color(0xFF9333EA), size: isDesktop ? 28 : 24),
              SizedBox(width: isDesktop ? 16 : 12),
              Text(
                'Focus Chapters',
                style: TextStyle(
                  fontSize: isDesktop ? 20 : 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 20 : 16),

          // Chapter list
          _buildChapterItem('Laws of Motion', 'Physics', 42, const Color(0xFF3B82F6), isDesktop: isDesktop),
          SizedBox(height: isDesktop ? 16 : 12),
          _buildChapterItem('Organic Chemistry', 'Chemistry', 38, const Color(0xFF10B981), isDesktop: isDesktop),
          SizedBox(height: isDesktop ? 16 : 12),
          _buildChapterItem('Calculus', 'Mathematics', 55, const Color(0xFF9333EA), isDesktop: isDesktop),

          SizedBox(height: isDesktop ? 20 : 16),
          TextButton(
            onPressed: () {},
            child: Text(
              'View All Chapters →',
              style: TextStyle(
                color: const Color(0xFF9333EA),
                fontWeight: FontWeight.w600,
                fontSize: isDesktop ? 15 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterItem(String title, String subject, int percentile, Color color, {required bool isDesktop}) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 18 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isDesktop ? 14 : 12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: isDesktop ? 10 : 8,
            height: isDesktop ? 10 : 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: isDesktop ? 14 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: isDesktop ? 4 : 2),
                Text(
                  subject,
                  style: TextStyle(
                    fontSize: isDesktop ? 14 : 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 14 : 12,
              vertical: isDesktop ? 8 : 6,
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$percentile%',
              style: TextStyle(
                color: Colors.white,
                fontSize: isDesktop ? 14 : 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockTestCard({required bool isDesktop}) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: isDesktop ? 52 : 48,
                height: isDesktop ? 52 : 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9333EA), Color(0xFFA855F7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.assignment, color: Colors.white, size: isDesktop ? 26 : 24),
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mock Tests',
                      style: TextStyle(
                        fontSize: isDesktop ? 20 : 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Full JEE Main simulation',
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 13,
                        color: const Color(0xFF9333EA),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          Text(
            '90 questions • 3 hours • Real JEE pattern',
            style: TextStyle(
              fontSize: isDesktop ? 15 : 14,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isDesktop ? 20 : 16),
          SizedBox(
            width: double.infinity,
            height: isDesktop ? 52 : 48,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9333EA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Start Mock Test',
                style: TextStyle(
                  fontSize: isDesktop ? 17 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnapSolveCard({required bool isDesktop}) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: isDesktop ? 52 : 48,
                height: isDesktop ? 52 : 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9333EA), Color(0xFFA855F7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.camera_alt, color: Colors.white, size: isDesktop ? 26 : 24),
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Snap & Solve',
                      style: TextStyle(
                        fontSize: isDesktop ? 20 : 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '15 snaps remaining',
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 13,
                        color: const Color(0xFF9333EA),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          Text(
            'Stuck on a problem? Just snap a photo and get instant step-by-step solutions!',
            style: TextStyle(
              fontSize: isDesktop ? 15 : 14,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isDesktop ? 20 : 16),
          SizedBox(
            width: double.infinity,
            height: isDesktop ? 52 : 48,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9333EA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Open Camera',
                style: TextStyle(
                  fontSize: isDesktop ? 17 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard({required bool isDesktop}) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Progress',
            style: TextStyle(
              fontSize: isDesktop ? 20 : 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isDesktop ? 20 : 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('65', 'Percentile', const Color(0xFF9333EA), isDesktop: isDesktop),
              ),
              Expanded(
                child: _buildStatItem('142', 'Questions', const Color(0xFF10B981), isDesktop: isDesktop),
              ),
              Expanded(
                child: _buildStatItem('7', 'Day Streak', const Color(0xFFF59E0B), isDesktop: isDesktop),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color, {required bool isDesktop}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: isDesktop ? 32 : 28,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        SizedBox(height: isDesktop ? 6 : 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isDesktop ? 14 : 13,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String text, {required bool isDesktop}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 14 : 12,
        vertical: isDesktop ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isDesktop ? 14 : 13,
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
