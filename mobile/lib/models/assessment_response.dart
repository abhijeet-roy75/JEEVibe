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
  final double overallTheta;
  final double overallPercentile;
  final int chaptersExplored;
  final int chaptersConfident;
  final Map<String, dynamic> subjectBalance;

  AssessmentData({
    required this.assessment,
    required this.thetaByChapter,
    required this.thetaBySubject,
    required this.overallTheta,
    required this.overallPercentile,
    required this.chaptersExplored,
    required this.chaptersConfident,
    required this.subjectBalance,
  });

  factory AssessmentData.fromJson(Map<String, dynamic> json) {
    return AssessmentData(
      assessment: json['assessment'] as Map<String, dynamic>,
      thetaByChapter: json['theta_by_chapter'] as Map<String, dynamic>,
      thetaBySubject: json['theta_by_subject'] as Map<String, dynamic>,
      overallTheta: (json['overall_theta'] as num).toDouble(),
      overallPercentile: (json['overall_percentile'] as num).toDouble(),
      chaptersExplored: json['chapters_explored'] as int,
      chaptersConfident: json['chapters_confident'] as int,
      subjectBalance: json['subject_balance'] as Map<String, dynamic>,
    );
  }
}
