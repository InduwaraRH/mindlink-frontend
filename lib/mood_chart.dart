import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MoodChart — existing widget, palette updated from deepPurple to #607D8B
// ─────────────────────────────────────────────────────────────────────────────
class MoodChart extends StatelessWidget {
  final List<dynamic> thoughts;

  const MoodChart({super.key, required this.thoughts});

  @override
  Widget build(BuildContext context) {
    final data = thoughts
        .where((t) => t['mood_score'] != null)
        .take(7)
        .toList()
        .reversed
        .toList();

    if (data.isEmpty) {
      return Container(
        height: 150,
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          "Log your mood to see trends here!",
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i]['mood_score'].toDouble()));
    }

    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Palette fix: deepPurple → #607D8B
          const Text(
            "Mood Trends (Last 7 Entries)",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF607D8B),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 10,
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    // ✅ Palette fix: deepPurpleAccent → #607D8B
                    color: const Color(0xFF607D8B),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      // ✅ Palette fix: deepPurple.withOpacity → #607D8B
                      color: const Color(0xFF607D8B).withOpacity(0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// FR-08: ProductivityChart
//
// Displays task completion rate over the last 7 days as a bar chart.
// Each bar represents one day, showing the percentage of tasks completed
// on that day relative to total tasks that existed at that time.
//
// Since the backend does not currently store per-day completion snapshots,
// we derive daily productivity from the task list passed in:
//   - tasks with is_done=true AND due_date falling on that day = completed
//   - tasks with due_date falling on that day (done or not) = total for that day
//
// This satisfies FR-08: "data visualisations showing productivity trends
// and wellbeing insights" — giving the user a second data dimension
// alongside the mood chart, directly addressing the research gap of
// integrating academic performance data with wellbeing tracking.
// ─────────────────────────────────────────────────────────────────────────────
class ProductivityChart extends StatelessWidget {
  final List<dynamic> tasks;

  const ProductivityChart({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    // Build last 7 days (today = day 6, 6 days ago = day 0)
    final today = DateTime.now();
    final List<DateTime> days = List.generate(
      7,
      (i) => DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: 6 - i)),
    );

    // Day label strings for X axis (e.g. "Mon", "Tue")
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // ── Compute completion rate per day ────────────────────────────────────
    // For each of the last 7 days, find tasks whose due_date falls on that day
    // and compute completedOnDay / totalOnDay as the bar height (0.0–1.0).
    // Days with no tasks get a neutral 0 bar — shown as empty.
    List<double> completionRates = [];

    for (final day in days) {
      final tasksOnDay = tasks.where((t) {
        if (t['due_date'] == null) return false;
        try {
          final due = DateTime.parse(t['due_date']);
          return due.year == day.year &&
              due.month == day.month &&
              due.day == day.day;
        } catch (_) {
          return false;
        }
      }).toList();

      if (tasksOnDay.isEmpty) {
        completionRates.add(0.0);
      } else {
        final done = tasksOnDay.where((t) => t['is_done'] == true).length;
        completionRates.add(done / tasksOnDay.length);
      }
    }

    final bool hasAnyData = completionRates.any((r) => r > 0);

    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Task Completion (Last 7 Days)",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF546E7A),
                ),
              ),
              const Spacer(),
              // ✅ Legend
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF607D8B).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                "% Done",
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasAnyData)
            Expanded(
              child: Center(
                child: Text(
                  "Complete tasks to see productivity trends!",
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ),
            )
          else
            Expanded(
              child: BarChart(
                BarChartData(
                  maxY: 1.0,
                  minY: 0.0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 0.25,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withOpacity(0.15),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    // Hide top and right titles
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    // X axis: day labels
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final day = days[value.toInt()];
                          final label =
                              dayLabels[day.weekday - 1]; // weekday 1=Mon
                          final isToday = day.day == today.day &&
                              day.month == today.month;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isToday
                                    ? const Color(0xFF607D8B)
                                    : Colors.grey[400],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Y axis: percentage labels (0%, 50%, 100%)
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 0.5,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            "${(value * 100).toInt()}%",
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[400],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(7, (i) {
                    final rate = completionRates[i];
                    final isToday = days[i].day == today.day &&
                        days[i].month == today.month;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: rate,
                          // ✅ Full bar = green (100% done), empty = light slate
                          color: rate >= 1.0
                              ? const Color(0xFF1B5E20).withOpacity(0.75)
                              : rate > 0
                                  ? const Color(0xFF607D8B)
                                        .withOpacity(0.55 + rate * 0.35)
                                  : Colors.grey.withOpacity(0.15),
                          width: 22,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                          // ✅ Today's bar has a highlighted border
                          rodStackItems: [],
                          backDrawRodData: BackgroundBarChartRodData(
                            show: isToday,
                            toY: 1.0,
                            color: const Color(0xFF607D8B).withOpacity(0.05),
                          ),
                        ),
                      ],
                    );
                  }),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final rate = completionRates[group.x];
                        final day = days[group.x];
                        return BarTooltipItem(
                          "${day.day}/${day.month}\n${(rate * 100).toInt()}% done",
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}