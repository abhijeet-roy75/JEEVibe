/// Mastery Chart Widget
/// Line chart for displaying mastery progression over time
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/analytics_data.dart';

class MasteryChart extends StatelessWidget {
  final MasteryTimeline timeline;
  final Color lineColor;
  final double height;

  const MasteryChart({
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
                reservedSize: 50, // Increased to fit percentage labels
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
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => AppColors.textPrimary,
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  if (index < 0 || index >= timeline.timeline.length) {
                    return null;
                  }
                  final point = timeline.timeline[index];
                  return LineTooltipItem(
                    '${point.percentile.toInt()}%\n${DateFormat('MMM d').format(point.date)}',
                    AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  List<FlSpot> _getSpots() {
    return timeline.timeline.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.percentile);
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
    
    String dateText;
    if (index == 0) {
      dateText = 'Day 1';
    } else if (index == timeline.timeline.length - 1) {
      dateText = 'Now';
    } else {
      // Show month abbreviation
      final monthName = DateFormat('MMM').format(point.date);
      dateText = monthName;
    }

    // Show percentage above date label
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${point.percentile.toInt()}%',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dateText,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 10,
            ),
          ),
        ],
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

/// Simple mini chart for overview display
class MasteryMiniChart extends StatelessWidget {
  final MasteryTimeline timeline;
  final Color lineColor;
  final double height;
  final double width;

  const MasteryMiniChart({
    super.key,
    required this.timeline,
    required this.lineColor,
    this.height = 60,
    this.width = 100,
  });

  @override
  Widget build(BuildContext context) {
    if (timeline.timeline.isEmpty || timeline.timeline.length < 2) {
      return SizedBox(
        height: height,
        width: width,
        child: Center(
          child: Text(
            '--',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: width,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
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
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withValues(alpha: 0.1),
              ),
            ),
          ],
          lineTouchData: const LineTouchData(enabled: false),
        ),
      ),
    );
  }

  List<FlSpot> _getSpots() {
    return timeline.timeline.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.percentile);
    }).toList();
  }
}
