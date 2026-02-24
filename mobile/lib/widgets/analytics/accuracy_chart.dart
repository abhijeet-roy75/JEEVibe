/// Accuracy Chart Widget
/// Line chart for displaying accuracy progression over time
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/analytics_data.dart';

class AccuracyChart extends StatelessWidget {
  final AccuracyTimeline timeline;
  final Color lineColor;
  final double height;

  const AccuracyChart({
    super.key,
    required this.timeline,
    required this.lineColor,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (timeline.timeline.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No data available yet',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ),
      );
    }

    // Determine which indices to show labels for (show at intervals to avoid clutter)
    final labelIndices = _getLabelIndices();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppColors.borderLight,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: _calculateXInterval(),
                getTitlesWidget: _bottomTitleWidget,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 25,
                reservedSize: 35,
                getTitlesWidget: _leftTitleWidget,
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: AppColors.borderDefault, width: 1),
              left: BorderSide(color: AppColors.borderDefault, width: 1),
            ),
          ),
          minX: 0,
          maxX: (timeline.timeline.length - 1).toDouble(),
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: _getSpots(),
              isCurved: true,
              curveSmoothness: 0.3,
              color: lineColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: lineColor,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withValues(alpha: 0.1),
              ),
              // Show percentage labels above key data points
              showingIndicators: labelIndices,
            ),
          ],
          showingTooltipIndicators: labelIndices.map((index) {
            return ShowingTooltipIndicators([
              LineBarSpot(
                LineChartBarData(spots: _getSpots()),
                0,
                _getSpots()[index],
              ),
            ]);
          }).toList(),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => Colors.transparent,
              tooltipRoundedRadius: 4,
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              tooltipMargin: 4,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  if (index < 0 || index >= timeline.timeline.length) {
                    return null;
                  }
                  final point = timeline.timeline[index];
                  return LineTooltipItem(
                    '${point.accuracy}%',
                    AppTextStyles.caption.copyWith(
                      color: lineColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,  // 12px iOS, 10.56px Android (was 11)
                    ),
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
        ),
      ),
    );
  }

  /// Get indices where we should show percentage labels
  List<int> _getLabelIndices() {
    final count = timeline.timeline.length;
    if (count == 0) return [];
    if (count == 1) return [0];
    if (count == 2) return [0, 1];
    if (count <= 4) return [0, count - 1];
    // For more points, show first, middle, and last
    return [0, count ~/ 2, count - 1];
  }

  List<FlSpot> _getSpots() {
    return timeline.timeline.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.accuracy.toDouble());
    }).toList();
  }

  double _calculateXInterval() {
    final count = timeline.timeline.length;
    if (count <= 5) return 1;
    if (count <= 10) return 2;
    if (count <= 20) return 4;
    return (count / 5).ceilToDouble();
  }

  Widget _bottomTitleWidget(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index < 0 || index >= timeline.timeline.length) {
      return const SizedBox.shrink();
    }

    final point = timeline.timeline[index];

    // Format date based on position
    String dateText;
    if (index == 0 && timeline.timeline.length > 1) {
      // First point - show "Jan 5" format
      dateText = DateFormat('MMM d').format(point.date);
    } else if (index == timeline.timeline.length - 1) {
      dateText = 'Today';
    } else {
      // Middle points - show "Jan 7" format
      dateText = DateFormat('MMM d').format(point.date);
    }

    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(
        dateText,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textTertiary,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _leftTitleWidget(double value, TitleMeta meta) {
    if (value % 25 != 0) return const SizedBox.shrink();

    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(
        '${value.toInt()}%',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textTertiary,
          fontSize: 10,
        ),
      ),
    );
  }
}
