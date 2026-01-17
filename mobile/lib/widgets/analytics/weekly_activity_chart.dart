/// Weekly Activity Chart Widget
/// Vertical bar chart showing questions answered per day for the week
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/analytics_data.dart';

class WeeklyActivityChart extends StatelessWidget {
  final WeeklyActivity activity;
  final double height;

  const WeeklyActivityChart({
    super.key,
    required this.activity,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    if (activity.week.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No activity data available',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ),
      );
    }

    // Find max questions for Y-axis scaling
    final maxQuestions = activity.week
        .map((d) => d.questions)
        .reduce((a, b) => a > b ? a : b);
    final double yMax = maxQuestions > 0 ? (maxQuestions * 1.2).ceil().toDouble() : 10.0;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: yMax,
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => AppColors.textPrimary,
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final day = activity.week[group.x.toInt()];
                return BarTooltipItem(
                  '${day.questions} Qs',
                  AppTextStyles.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= activity.week.length) {
                    return const SizedBox.shrink();
                  }
                  final day = activity.week[index];
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      day.dayName,
                      style: AppTextStyles.caption.copyWith(
                        color: day.isToday
                            ? AppColors.primaryPurple
                            : AppColors.textTertiary,
                        fontWeight:
                            day.isToday ? FontWeight.bold : FontWeight.normal,
                        fontSize: 11,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: activity.week.asMap().entries.map((entry) {
            final index = entry.key;
            final day = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: day.questions.toDouble(),
                  color: day.isToday
                      ? AppColors.primaryPurple
                      : AppColors.primaryPurple.withValues(alpha: 0.5),
                  width: 28,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
