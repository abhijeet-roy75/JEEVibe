import 'dart:io';
import 'package:flutter/material.dart';
import '../models/solution_model.dart';
import 'followup_quiz_screen.dart';
import '../widgets/latex_widget.dart';
import '../theme/jeevibe_theme.dart';

class SolutionScreen extends StatefulWidget {
  final Future<Solution> solutionFuture;
  final File? imageFile;

  const SolutionScreen({
    super.key, 
    required this.solutionFuture,
    this.imageFile,
  });

  @override
  State<SolutionScreen> createState() => _SolutionScreenState();
}

class _SolutionScreenState extends State<SolutionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JVColors.background,
      body: FutureBuilder<Solution>(
        future: widget.solutionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          } else if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          } else if (snapshot.hasData) {
            return _buildContent(snapshot.data!);
          } else {
            return _buildErrorState("Unknown error occurred");
          }
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: JVColors.headerGradient,
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: JVColors.primary,
                  strokeWidth: 4,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Analyzing Question...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Priya Ma'am is working on it!",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
            if (widget.imageFile != null) ...[
              const SizedBox(height: 48),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    widget.imageFile!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: JVColors.error),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong.',
              style: JVStyles.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: JVStyles.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Solution solution) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 1. Success Header (Purple Gradient)
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: JVColors.headerGradient,
            ),
            child: Stack(
              children: [
                // Decorative Circles
                Positioned(
                  top: -64,
                  right: -64,
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -48,
                  left: -48,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                
                // Content
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 64), // Reduced padding
                    child: Column(
                      children: [
                        // Top Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                                ),
                                child: const Text(
                                  'Question Recognized!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 40), // Balance
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Success Icon
                        Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.check_circle,
                              color: JVColors.primary,
                              size: 36,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            solution.topic,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          solution.difficulty,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Overlapping Question Card
          Transform.translate(
            offset: const Offset(0, -32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Question Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: JVStyles.cardDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: JVColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.menu_book, size: 16, color: JVColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "HERE'S WHAT I SEE:",
                                    style: JVStyles.bodySmall.copyWith(
                                      color: JVColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildQuestionText(solution.recognizedQuestion),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        if (widget.imageFile != null) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              widget.imageFile!,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Solution Steps
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: JVColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Step-by-Step Solution', style: JVStyles.h2),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Approach
                  if (solution.solution.approach.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: JVColors.divider),
                      ),
                      child: Text(
                        solution.solution.approach,
                        style: JVStyles.bodyMedium,
                      ),
                    ),

                  // Steps
                  ...solution.solution.steps.asMap().entries.map((entry) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: JVColors.divider),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: JVColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${entry.key + 1}',
                                style: const TextStyle(
                                  color: JVColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            'Step ${entry.key + 1}',
                            style: JVStyles.h3.copyWith(fontSize: 16),
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: JVColors.surfaceGrey,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: LaTeXWidget(
                                text: entry.value,
                                textStyle: JVStyles.bodyLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // 4. Final Answer (Green Gradient)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: JVColors.finalAnswerGradient,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: JVColors.success.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: JVColors.success, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'FINAL ANSWER',
                              style: JVStyles.bodySmall.copyWith(
                                color: JVColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LaTeXWidget(
                          text: solution.solution.finalAnswer,
                          textStyle: JVStyles.h1.copyWith(color: const Color(0xFF047857)), // Dark Green
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 5. Priya Ma'am Tip (Purple/Pink Gradient)
                  if (solution.solution.priyaMaamTip.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: JVColors.priyaCardGradient,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              gradient: JVColors.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'P',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      "Priya Ma'am's Tip",
                                      style: JVStyles.h3.copyWith(color: const Color(0xFF6B21A8)),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.auto_awesome, size: 16, color: JVColors.primary),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  solution.solution.priyaMaamTip,
                                  style: JVStyles.bodyMedium.copyWith(color: const Color(0xFF581C87)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 32),

                  // 6. Practice Section (Blue Gradient)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEFF6FF), Color(0xFFEEF2FF)], // Blue-50 to Indigo-50
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Practice Similar Questions', style: JVStyles.h3),
                                  Text(
                                    'Master this concept with 3 follow-up questions',
                                    style: JVStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Difficulty Preview
                        Row(
                          children: [
                            _buildDifficultyChip('Basic', 'Q1', Colors.green),
                            const SizedBox(width: 8),
                            _buildDifficultyChip('Intermediate', 'Q2', Colors.orange),
                            const SizedBox(width: 8),
                            _buildDifficultyChip('Advanced', 'Q3', Colors.red),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => FollowUpQuizScreen(
                                    recognizedQuestion: solution.recognizedQuestion,
                                    solution: solution.solution,
                                    topic: solution.topic,
                                    difficulty: solution.difficulty,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              padding: EdgeInsets.zero,
                              shadowColor: Colors.transparent,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.play_arrow, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Start Practice',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyChip(String label, String subLabel, MaterialColor color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.shade200),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color.shade700,
              ),
            ),
            Text(
              subLabel,
              style: TextStyle(
                fontSize: 10,
                color: color.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionText(String questionText) {
    final imagePattern = RegExp(r'\[(image|Image|diagram|Diagram|figure|Figure)\]', caseSensitive: false);
    if (imagePattern.hasMatch(questionText)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LaTeXWidget(
            text: questionText.replaceAll(imagePattern, ''),
            textStyle: JVStyles.bodyLarge,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.image_outlined, color: JVColors.textTertiary, size: 16),
              const SizedBox(width: 8),
              Text(
                'Refer to original image',
                style: JVStyles.bodySmall,
              ),
            ],
          ),
        ],
      );
    }
    
    return LaTeXWidget(
      text: questionText,
      textStyle: JVStyles.bodyLarge,
    );
  }
}

