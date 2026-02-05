import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MoodHistoryScreen extends StatefulWidget {
  final int userId;

  const MoodHistoryScreen({super.key, required this.userId});

  @override
  State<MoodHistoryScreen> createState() => _MoodHistoryScreenState();
}

class _MoodHistoryScreenState extends State<MoodHistoryScreen> {
  List<dynamic> allThoughts = []; // Stores all data
  List<dynamic> filteredThoughts = []; // Stores filtered data
  bool isLoading = true;

  // --- FILTER STATES ---
  DateTime? _selectedDate; // Null means "All Time"
  String _selectedMoodFilter = 'All'; // Options: All, Low (1-3), Mid (4-7), High (8-10)

  @override
  void initState() {
    super.initState();
    fetchAllThoughts();
  }

  // --- 1. FETCH DATA ---
  Future<void> fetchAllThoughts() async {
    final url = Uri.parse('http://10.0.2.2:8000/thoughts/${widget.userId}');
    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        // DEBUG: Print the first item to check the date field name
        if (data.isNotEmpty) {
          print("DEBUG DATA SAMPLE: ${data.first}"); 
        }

        setState(() {
          allThoughts = data.reversed.toList();
          _applyFilters(); // Initial filter application
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error: $e");
      setState(() => isLoading = false);
    }
  }

  // --- 2. DELETE DATA ---
  Future<void> deleteThought(int id) async {
    final url = Uri.parse('http://10.0.2.2:8000/thoughts/$id');
    try {
      await http.delete(url);
      fetchAllThoughts(); // Refresh list after delete
    } catch (e) { print(e); }
  }

  // --- 3. FILTER LOGIC ---
  void _applyFilters() {
    setState(() {
      filteredThoughts = allThoughts.where((item) {
        // 1. Date Filter
        bool matchesDate = true;
        if (_selectedDate != null) {
          final itemDateStr = item['created_at']; // Ensure this matches your DB column name
          if (itemDateStr != null) {
            final itemDate = DateTime.parse(itemDateStr).toLocal();
            matchesDate = itemDate.year == _selectedDate!.year &&
                          itemDate.month == _selectedDate!.month &&
                          itemDate.day == _selectedDate!.day;
          } else {
            matchesDate = false;
          }
        }

        // 2. Mood Filter
        bool matchesMood = true;
        int score = item['mood_score'] ?? 5;
        if (_selectedMoodFilter == 'Low (1-3)') matchesMood = score <= 3;
        else if (_selectedMoodFilter == 'Mid (4-7)') matchesMood = score > 3 && score <= 7;
        else if (_selectedMoodFilter == 'High (8-10)') matchesMood = score > 7;

        return matchesDate && matchesMood;
      }).toList();
    });
  }

  // --- 4. HELPERS ---
  String formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return "Date not available";
    try {
      final DateTime dt = DateTime.parse(isoString).toLocal();
      // Simple custom formatting to avoid 'intl' package dependency if not installed
      final date = "${dt.month}/${dt.day}/${dt.year}"; 
      final String period = dt.hour >= 12 ? "PM" : "AM";
      int hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
      hour = hour == 0 ? 12 : hour;
      final String minute = dt.minute.toString().padLeft(2, '0');
      
      return "$date • $hour:$minute $period";
    } catch (e) {
      return "Invalid Date Format";
    }
  }

  Color getMoodColor(int score) {
    if (score <= 3) return Colors.redAccent;
    if (score <= 7) return Colors.orangeAccent;
    return Colors.green;
  }

  String getMoodEmoji(int score) {
    if (score <= 3) return "😫";
    if (score <= 7) return "😐";
    return "🤩";
  }

  // --- 5. UI BUILDER ---
@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Mood History"),
        backgroundColor: Colors.white,
        // CHANGE THIS LINE: from Colors.white to Colors.black
        foregroundColor: Colors.black, 
        elevation: 0,
        actions: [
          // Date Filter Button
          IconButton(
            icon: Icon(
              Icons.calendar_today,
              // Ensure the icon color is also visible when not selected
              color: _selectedDate != null ? Colors.deepPurple : Colors.grey[600]
            ),
            onPressed: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null && picked != _selectedDate) {
                setState(() => _selectedDate = picked);
                _applyFilters();
              }
            },
          ),
          // Clear Filters Button
          if (_selectedDate != null || _selectedMoodFilter != 'All')
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.red),
              onPressed: () {
                setState(() {
                  _selectedDate = null;
                  _selectedMoodFilter = 'All';
                });
                _applyFilters();
              },
            )
        ],
      ),
      body: Column(
        children: [
          // --- FILTER CHIPS ROW ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text("Filter Mood: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(width: 8),
                  _buildFilterChip('All', Colors.grey),
                  const SizedBox(width: 8),
                  _buildFilterChip('Low (1-3)', Colors.redAccent),
                  const SizedBox(width: 8),
                  _buildFilterChip('Mid (4-7)', Colors.orangeAccent),
                  const SizedBox(width: 8),
                  _buildFilterChip('High (8-10)', Colors.green),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // --- LIST VIEW ---
          Expanded(
            child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredThoughts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.filter_list_off, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 10),
                          const Text("No records match your filters", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredThoughts.length,
                      itemBuilder: (context, index) {
                        final item = filteredThoughts[index];
                        final mood = item['mood_score'] ?? 5;
                        // Use correct key 'created_at' (change if your backend uses 'date' or 'timestamp')
                        final dateStr = formatDateTime(item['created_at']); 

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200)
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: getMoodColor(mood).withOpacity(0.1),
                              child: Text(getMoodEmoji(mood), style: const TextStyle(fontSize: 20)),
                            ),
                            title: Text(
                              item['content'] ?? "No content", 
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: getMoodColor(mood).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4)
                                    ),
                                    child: Text(
                                      "Score: $mood",
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: getMoodColor(mood)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                                  const SizedBox(width: 4),
                                  Text(dateStr, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                                ],
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.grey),
                              onPressed: () => deleteThought(item['id']),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, Color color) {
    final bool isSelected = _selectedMoodFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          _selectedMoodFilter = label; 
          _applyFilters();
        });
      },
      backgroundColor: Colors.white,
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.black54,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? color : Colors.grey.shade300)
      ),
    );
  }
}