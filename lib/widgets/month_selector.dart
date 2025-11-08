import 'package:flutter/material.dart';

class MonthSelector extends StatefulWidget {
  final List<DateTime> selected;
  final ValueChanged<List<DateTime>> onChanged;

  const MonthSelector({super.key, required this.selected, required this.onChanged});

  @override
  State<MonthSelector> createState() => _MonthSelectorState();
}

class _MonthSelectorState extends State<MonthSelector> {
  late List<DateTime> temp;

  @override
  void initState() {
    super.initState();
    temp = List.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    // Generate last 12 months
    final months = List.generate(12, (i) {
      final now = DateTime.now();
      return DateTime(now.year, now.month - i);
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 50),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Select Months", style: TextStyle(fontSize: 20)),
          const SizedBox(height: 10),

          SizedBox(
            height: 250, // scroll area fixed
            child: ListView(
              shrinkWrap: true,
              children: months.map((m) {
                final label = "${m.month}-${m.year}";
                return CheckboxListTile(
                  value: temp.any((x) => x.month == m.month && x.year == m.year),
                  title: Text(label),
                  onChanged: (v) {
                    if (v == true) temp.add(m);
                    else temp.removeWhere((x) => x.month == m.month && x.year == m.year);
                    setState(() {});
                  },
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onChanged(temp);
                Navigator.pop(context);
              },
              child: const Text("Apply Filter"),
            ),
          ),
        ],
      ),
    );
  }
}
