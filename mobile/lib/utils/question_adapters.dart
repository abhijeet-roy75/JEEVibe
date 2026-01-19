/// Question Adapters
///
/// Utility functions to convert between Chapter Practice models and Daily Quiz models.
/// This allows reuse of Daily Quiz widgets (FeedbackBanner, DetailedExplanation, QuestionCard)
/// in the Chapter Practice flow.

import '../models/chapter_practice_models.dart';
import '../models/daily_quiz_question.dart';
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
    // Convert PracticeSolutionStep to SolutionStep with full structure
    // This preserves description, explanation, formula, and calculation fields
    solutionSteps: result.solutionSteps
        .map((step) => SolutionStep(
              stepNumber: step.stepNumber,
              description: step.description,
              explanation: step.explanation,
              formula: step.formula,
              calculation: step.calculation,
            ))
        .toList(),
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
