/// Question Adapters
///
/// Utility functions to convert between various question models and Daily Quiz models.
/// This allows reuse of Daily Quiz widgets (FeedbackBanner, DetailedExplanation, QuestionCard)
/// in multiple flows: Chapter Practice, Snap Practice, etc.

import '../models/chapter_practice_models.dart';
import '../models/daily_quiz_question.dart';
import '../models/solution_model.dart' show FollowUpQuestion;
import '../models/assessment_question.dart' show QuestionOption;

/// Convert PracticeQuestion to DailyQuizQuestion
///
/// Enables reuse of Daily Quiz widgets for Chapter Practice questions.
/// Handles MCQ and numerical question types.
DailyQuizQuestion practiceQuestionToDailyQuiz(PracticeQuestion practice) {
  return DailyQuizQuestion(
    questionId: practice.questionId,
    position: practice.position,
    subject: practice.subject,
    chapter: practice.chapter,
    chapterKey: practice.chapterKey,
    questionType: practice.questionType,
    questionText: practice.questionText,
    questionTextHtml: practice.questionTextHtml,
    options: practice.options
        .map((o) => QuestionOption(
              optionId: o.optionId,
              text: o.text,
              html: o.html,
            ))
        .toList(),
    imageUrl: practice.imageUrl,
    answered: practice.answered,
    studentAnswer: practice.studentAnswer,
    isCorrect: practice.isCorrect,
    timeTakenSeconds: practice.timeTakenSeconds,
  );
}

/// Convert PracticeAnswerResult to AnswerFeedback
///
/// Enables reuse of FeedbackBannerWidget and DetailedExplanationWidget
/// for Chapter Practice answer feedback.
///
/// Parameters:
/// - [result]: The answer result from the chapter practice submit-answer API
/// - [questionId]: The question ID (required for widget identification)
/// - [timeTakenSeconds]: Time spent on the question (defaults to 0)
/// - [questionType]: The question type ('mcq_single' or 'numerical')
AnswerFeedback practiceResultToFeedback(
  PracticeAnswerResult result, {
  required String questionId,
  int timeTakenSeconds = 0,
  String? questionType,
}) {
  return AnswerFeedback(
    questionId: questionId,
    isCorrect: result.isCorrect,
    correctAnswer: result.correctAnswer,
    correctAnswerText: result.correctAnswerText,
    explanation: result.explanation,
    solutionText: result.solutionText,
    // Both models now use unified SolutionStep - no conversion needed
    solutionSteps: result.solutionSteps,
    keyInsight: result.keyInsight,
    distractorAnalysis: result.distractorAnalysis,
    commonMistakes: result.commonMistakes,
    timeTakenSeconds: timeTakenSeconds,
    studentAnswer: result.studentAnswer,
    questionType: questionType,
  );
}

/// Convert a list of PracticeQuestions to DailyQuizQuestions
///
/// Useful for batch conversion when displaying multiple questions.
List<DailyQuizQuestion> practiceQuestionsToDailyQuiz(
    List<PracticeQuestion> questions) {
  return questions.map(practiceQuestionToDailyQuiz).toList();
}

/// Create AnswerFeedback from PracticeQuestion and PracticeAnswerResult
///
/// Convenience method that extracts context from the question.
/// Use this when you have both the question and the result available.
AnswerFeedback createFeedbackFromPractice({
  required PracticeQuestion question,
  required PracticeAnswerResult result,
  required int timeTakenSeconds,
}) {
  return practiceResultToFeedback(
    result,
    questionId: question.questionId,
    timeTakenSeconds: timeTakenSeconds,
    questionType: question.questionType,
  );
}

// =============================================================================
// SNAP PRACTICE ADAPTERS
// =============================================================================

/// Convert FollowUpQuestion to DailyQuizQuestion
///
/// Enables reuse of Daily Quiz widgets (QuestionCard) for Snap Practice questions.
/// Handles MCQ and numerical question types.
///
/// Parameters:
/// - [followUp]: The FollowUpQuestion from snap practice
/// - [position]: The question position (1-3)
/// - [subject]: The subject name
/// - [topic]: The topic/chapter name
DailyQuizQuestion followUpQuestionToDailyQuiz(
  FollowUpQuestion followUp, {
  required int position,
  required String subject,
  required String topic,
}) {
  // Convert Map<String, String> options to List<QuestionOption>
  final List<QuestionOption> optionsList = followUp.options.entries
      .map((entry) => QuestionOption(
            optionId: entry.key,
            text: entry.value,
            html: null,
          ))
      .toList();

  // Sort options by key (A, B, C, D)
  optionsList.sort((a, b) => a.optionId.compareTo(b.optionId));

  return DailyQuizQuestion(
    questionId: followUp.questionId ?? 'snap_q_$position',
    position: position,
    subject: subject,
    chapter: topic,
    chapterKey: '${subject.toLowerCase()}_${topic.toLowerCase().replaceAll(' ', '_')}',
    questionType: followUp.questionType,
    questionText: followUp.question,
    questionTextHtml: null, // FollowUpQuestion doesn't have HTML version
    options: optionsList.isNotEmpty ? optionsList : null,
  );
}

/// Create AnswerFeedback from FollowUpQuestion after answering
///
/// Enables reuse of FeedbackBannerWidget and DetailedExplanationWidget
/// for Snap Practice answer feedback.
///
/// Parameters:
/// - [followUp]: The FollowUpQuestion that was answered
/// - [isCorrect]: Whether the answer was correct
/// - [studentAnswer]: The student's answer
/// - [timeTakenSeconds]: Time spent on the question
AnswerFeedback followUpQuestionToFeedback(
  FollowUpQuestion followUp, {
  required bool isCorrect,
  required String? studentAnswer,
  int timeTakenSeconds = 0,
}) {
  // Convert explanation steps to SolutionStep format
  final solutionSteps = followUp.explanation.steps
      .map((step) => SolutionStep(description: step))
      .toList();

  return AnswerFeedback(
    questionId: followUp.questionId ?? '',
    isCorrect: isCorrect,
    correctAnswer: followUp.correctAnswer,
    correctAnswerText: followUp.explanation.finalAnswer,
    explanation: followUp.explanation.approach,
    solutionText: followUp.explanation.approach,
    solutionSteps: solutionSteps,
    keyInsight: followUp.priyaMaamNote,
    timeTakenSeconds: timeTakenSeconds,
    studentAnswer: studentAnswer,
    questionType: followUp.questionType,
  );
}
