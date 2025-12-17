/// Assessment Response Model
/// Represents a student's answer to an assessment question
class AssessmentResponse {
  final String questionId;
  final String studentAnswer;
  final int timeTakenSeconds;

  AssessmentResponse({
    required this.questionId,
    required this.studentAnswer,
    required this.timeTakenSeconds,
  });

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      'student_answer': studentAnswer,
      'time_taken_seconds': timeTakenSeconds,
    };
  }
}

/// Assessment Submission Result
/// Response from backend after submitting assessment
class AssessmentResult {
  final bool success;
  final String? error;
  final AssessmentData? data;

  AssessmentResult({
    required this.success,
    this.error,
    this.data,
  });

  factory AssessmentResult.fromJson(Map<String, dynamic> json) {
    // Handle processing status
    if (json['status'] == 'processing') {
      return AssessmentResult(
        success: true,
        data: AssessmentData(
          assessment: {'status': 'processing'},
          thetaByChapter: {},
          thetaBySubject: {},
          subjectAccuracy: {
            'physics': {'accuracy': null, 'correct': 0, 'total': 0},
            'chemistry': {'accuracy': null, 'correct': 0, 'total': 0},
            'mathematics': {'accuracy': null, 'correct': 0, 'total': 0},
          },
          overallTheta: 0,
          overallPercentile: 0,
          chaptersExplored: 0,
          chaptersConfident: 0,
          subjectBalance: {},
        ),
      );
    }
    
    return AssessmentResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      data: json['success'] == true && json['assessment'] != null
          ? AssessmentData.fromJson(json)
          : null,
    );
  }
}

class AssessmentData {
  final Map<String, dynamic> assessment;
  final Map<String, dynamic> thetaByChapter;
  final Map<String, dynamic> thetaBySubject;
  final Map<String, dynamic> subjectAccuracy;
  final double overallTheta;
  final double overallPercentile;
  final int chaptersExplored;
  final int chaptersConfident;
  final Map<String, dynamic> subjectBalance;

  AssessmentData({
    required this.assessment,
    required this.thetaByChapter,
    required this.thetaBySubject,
    required this.subjectAccuracy,
    required this.overallTheta,
    required this.overallPercentile,
    required this.chaptersExplored,
    required this.chaptersConfident,
    required this.subjectBalance,
  });

  factory AssessmentData.fromJson(Map<String, dynamic> json) {
    // Parse subject_accuracy with proper type handling
    Map<String, dynamic> subjectAccuracy = {};
    if (json['subject_accuracy'] != null && json['subject_accuracy'] is Map) {
      final rawAccuracy = Map<String, dynamic>.from(json['subject_accuracy'] as Map);
      for (final entry in rawAccuracy.entries) {
        final subject = entry.key;
        final data = entry.value;
        if (data is Map) {
          subjectAccuracy[subject] = {
            'accuracy': data['accuracy'] != null 
                ? (data['accuracy'] is int ? data['accuracy'] : (data['accuracy'] as num).toDouble())
                : null,
            'correct': data['correct'] ?? 0,
            'total': data['total'] ?? 0,
          };
        }
      }
    }
    
    // Default if not provided
    if (subjectAccuracy.isEmpty) {
      subjectAccuracy = {
        'physics': {'accuracy': null, 'correct': 0, 'total': 0},
        'chemistry': {'accuracy': null, 'correct': 0, 'total': 0},
        'mathematics': {'accuracy': null, 'correct': 0, 'total': 0},
      };
    }
    
    // Extract assessment data (might be nested or at top level)
    final assessmentMap = json['assessment'] is Map 
        ? Map<String, dynamic>.from(json['assessment'] as Map)
        : <String, dynamic>{};
    
    // Try to get overall_theta and overall_percentile from assessment object first, then top level
    final overallTheta = (assessmentMap['overall_theta'] as num?)?.toDouble() 
        ?? (json['overall_theta'] as num?)?.toDouble() 
        ?? 0.0;
    final overallPercentile = (assessmentMap['overall_percentile'] as num?)?.toDouble()
        ?? (json['overall_percentile'] as num?)?.toDouble()
        ?? 0.0;
    
    return AssessmentData(
      assessment: assessmentMap,
      thetaByChapter: json['theta_by_chapter'] is Map 
          ? Map<String, dynamic>.from(json['theta_by_chapter'] as Map)
          : {},
      thetaBySubject: json['theta_by_subject'] is Map
          ? Map<String, dynamic>.from(json['theta_by_subject'] as Map)
          : {},
      subjectAccuracy: subjectAccuracy,
      overallTheta: overallTheta,
      overallPercentile: overallPercentile,
      chaptersExplored: json['chapters_explored'] as int? ?? 0,
      chaptersConfident: json['chapters_confident'] as int? ?? 0,
      subjectBalance: json['subject_balance'] is Map
          ? Map<String, dynamic>.from(json['subject_balance'] as Map)
          : {},
    );
  }
}
