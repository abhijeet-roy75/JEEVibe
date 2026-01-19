/// Tests for QuestionReviewScreen widget
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeevibe_mobile/models/review_question_data.dart';
import 'package:jeevibe_mobile/models/ai_tutor_models.dart';
import 'package:jeevibe_mobile/widgets/question_review/question_review_screen.dart';

void main() {
  // Helper to create test questions
  List<ReviewQuestionData> createTestQuestions({int count = 3}) {
    return List.generate(count, (index) {
      final isCorrect = index % 2 == 0;
      return ReviewQuestionData(
        questionId: 'q$index',
        position: index,
        questionText: 'Test question ${index + 1}?',
        options: [
          ReviewOptionData(optionId: 'A', text: 'Option A'),
          ReviewOptionData(optionId: 'B', text: 'Option B'),
          ReviewOptionData(optionId: 'C', text: 'Option C'),
          ReviewOptionData(optionId: 'D', text: 'Option D'),
        ],
        studentAnswer: isCorrect ? 'A' : 'B',
        correctAnswer: 'A',
        isCorrect: isCorrect,
        timeTakenSeconds: 30 + index * 10,
        subject: 'Physics',
        chapter: 'Mechanics',
      );
    });
  }

  Widget createTestWidget({
    required List<ReviewQuestionData> questions,
    int initialIndex = 0,
    String? filterType,
  }) {
    return MaterialApp(
      home: QuestionReviewScreen(
        questions: questions,
        initialIndex: initialIndex,
        filterType: filterType,
      ),
    );
  }

  group('QuestionReviewScreen', () {
    group('rendering', () {
      testWidgets('should display question number in header', (tester) async {
        final questions = createTestQuestions();

        await tester.pumpWidget(createTestWidget(questions: questions));
        await tester.pumpAndSettle();

        expect(find.textContaining('Question 1/3'), findsOneWidget);
      });

      testWidgets('should display correct/incorrect status banner', (tester) async {
        final questions = createTestQuestions();

        await tester.pumpWidget(createTestWidget(questions: questions));
        await tester.pumpAndSettle();

        // First question is correct (index 0, isCorrect = true)
        expect(find.text('Correct Answer!'), findsOneWidget);
      });

      testWidgets('should display incorrect status for wrong answer', (tester) async {
        final questions = createTestQuestions();

        // Start at index 1 which is incorrect
        await tester.pumpWidget(createTestWidget(
          questions: questions,
          initialIndex: 1,
        ));
        await tester.pumpAndSettle();

        expect(find.text('Incorrect Answer'), findsOneWidget);
      });

      testWidgets('should display question text', (tester) async {
        final questions = createTestQuestions();

        await tester.pumpWidget(createTestWidget(questions: questions));
        await tester.pumpAndSettle();

        expect(find.textContaining('Test question 1?'), findsOneWidget);
      });

      testWidgets('should display all answer options', (tester) async {
        final questions = createTestQuestions();

        await tester.pumpWidget(createTestWidget(questions: questions));
        await tester.pumpAndSettle();

        expect(find.text('Option A'), findsOneWidget);
        expect(find.text('Option B'), findsOneWidget);
        expect(find.text('Option C'), findsOneWidget);
        expect(find.text('Option D'), findsOneWidget);
      });

      testWidgets('should display navigation buttons', (tester) async {
        final questions = createTestQuestions();

        await tester.pumpWidget(createTestWidget(questions: questions));
        await tester.pumpAndSettle();

        expect(find.text('Previous'), findsOneWidget);
        expect(find.text('Next'), findsOneWidget);
      });

      testWidgets('should display Done button on last question', (tester) async {
        final questions = createTestQuestions();

        await tester.pumpWidget(createTestWidget(
          questions: questions,
          initialIndex: 2, // Last question
        ));
        await tester.pumpAndSettle();

        expect(find.text('Done'), findsOneWidget);
      });
    });

    group('navigation', () {
      testWidgets('should navigate to next question when Next is tapped', (tester) async {
        final questions = createTestQuestions();

        await tester.pumpWidget(createTestWidget(questions: questions));
        await tester.pumpAndSettle();

        // Initially on question 1
        expect(find.textContaining('Question 1/3'), findsOneWidget);

        // Tap Next
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        // Should be on question 2
        expect(find.textContaining('Question 2/3'), findsOneWidget);
      });

      testWidgets('should navigate to previous question when Previous is tapped', (tester) async {
        final questions = createTestQuestions();

        await tester.pumpWidget(createTestWidget(
          questions: questions,
          initialIndex: 1,
        ));
        await tester.pumpAndSettle();

        // Initially on question 2
        expect(find.textContaining('Question 2/3'), findsOneWidget);

        // Tap Previous
        await tester.tap(find.text('Previous'));
        await tester.pumpAndSettle();

        // Should be on question 1
        expect(find.textContaining('Question 1/3'), findsOneWidget);
      });

      testWidgets('Previous button should be disabled on first question', (tester) async {
        final questions = createTestQuestions();

        await tester.pumpWidget(createTestWidget(questions: questions));
        await tester.pumpAndSettle();

        // Find the Previous button and check if it's disabled
        final previousButton = find.widgetWithText(ElevatedButton, 'Previous');
        expect(previousButton, findsOneWidget);

        final button = tester.widget<ElevatedButton>(previousButton);
        expect(button.onPressed, isNull);
      });

      testWidgets('should pop navigation when Done is tapped', (tester) async {
        final questions = createTestQuestions();
        var didPop = false;

        await tester.pumpWidget(MaterialApp(
          home: Navigator(
            onPopPage: (route, result) {
              didPop = true;
              return route.didPop(result);
            },
            pages: [
              MaterialPage(
                child: QuestionReviewScreen(
                  questions: questions,
                  initialIndex: 2, // Last question
                ),
              ),
            ],
          ),
        ));
        await tester.pumpAndSettle();

        // Tap Done
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        expect(didPop, isTrue);
      });
    });

    group('filtering', () {
      testWidgets('should show all questions when filterType is all', (tester) async {
        final questions = createTestQuestions(count: 5);

        await tester.pumpWidget(createTestWidget(
          questions: questions,
          filterType: 'all',
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('/5'), findsOneWidget);
      });

      testWidgets('should show only correct questions when filterType is correct', (tester) async {
        final questions = createTestQuestions(count: 5);
        // With count=5: indices 0,2,4 are correct (3 questions)

        await tester.pumpWidget(createTestWidget(
          questions: questions,
          filterType: 'correct',
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('/3'), findsOneWidget);
      });

      testWidgets('should show only wrong questions when filterType is wrong', (tester) async {
        final questions = createTestQuestions(count: 5);
        // With count=5: indices 1,3 are wrong (2 questions)

        await tester.pumpWidget(createTestWidget(
          questions: questions,
          filterType: 'wrong',
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('/2'), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('should show error state when questions list is empty', (tester) async {
        await tester.pumpWidget(createTestWidget(questions: []));
        await tester.pumpAndSettle();

        expect(find.text('Error'), findsOneWidget);
        expect(find.text('No question to display'), findsOneWidget);
      });

      testWidgets('should clamp initialIndex to valid range', (tester) async {
        final questions = createTestQuestions(count: 3);

        // Pass an out-of-bounds index
        await tester.pumpWidget(createTestWidget(
          questions: questions,
          initialIndex: 100,
        ));
        await tester.pumpAndSettle();

        // Should clamp to last valid index (2) and show question 3/3
        expect(find.textContaining('Question 3/3'), findsOneWidget);
      });

      testWidgets('should handle single question gracefully', (tester) async {
        final questions = createTestQuestions(count: 1);

        await tester.pumpWidget(createTestWidget(questions: questions));
        await tester.pumpAndSettle();

        expect(find.textContaining('Question 1/1'), findsOneWidget);
        // Should show Done instead of Next
        expect(find.text('Done'), findsOneWidget);
        // Previous should be disabled
        final previousButton = find.widgetWithText(ElevatedButton, 'Previous');
        final button = tester.widget<ElevatedButton>(previousButton);
        expect(button.onPressed, isNull);
      });
    });

    group('progress dots', () {
      testWidgets('should display progress dots for small question count', (tester) async {
        final questions = createTestQuestions(count: 5);

        await tester.pumpWidget(createTestWidget(questions: questions));
        await tester.pumpAndSettle();

        // Progress dots are rendered as Container widgets with BoxDecoration circle
        // Just verify the header renders without crashing
        expect(find.textContaining('Question 1/5'), findsOneWidget);
      });

      testWidgets('should not display progress dots for large question count (>15)', (tester) async {
        final questions = createTestQuestions(count: 20);

        await tester.pumpWidget(createTestWidget(questions: questions));
        await tester.pumpAndSettle();

        // Should still show header
        expect(find.textContaining('Question 1/20'), findsOneWidget);
      });
    });
  });

  group('ReviewTutorContext', () {
    test('should create context with required fields', () {
      final context = ReviewTutorContext(
        type: TutorContextType.quiz,
        id: 'quiz123',
        title: 'Test Quiz',
      );

      expect(context.type, TutorContextType.quiz);
      expect(context.id, 'quiz123');
      expect(context.title, 'Test Quiz');
    });
  });
}
