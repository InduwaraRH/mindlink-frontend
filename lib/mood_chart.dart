import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MoodChart extends StatelessWidget {
  final List<dynamic> thoughts;

  const MoodChart({super.key, required this.thoughts});

  @override
  Widget build(BuildContext context) {
    // 1. Prepare Data: Take the last 7 entries with a score
    // We reverse them so the oldest is on the left, newest on the right
    final data = thoughts
        .where((t) => t['mood_score'] != null)
        .take(7) 
        .toList()
        .reversed
        .toList();

    if (data.isEmpty) {
      // If no data, show a placeholder
      return Container(
        height: 150,
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: const Text("Log your mood to see trends here!"),
      );
    }

    // 2. Convert data into "Spots" (X, Y coordinates)
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
        boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Mood Trends (Last 7 Entries)", 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple)
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 10,
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false), // Hide numbers for cleaner look
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.deepPurpleAccent,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.deepPurple.withOpacity(0.15),
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