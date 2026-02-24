import 'package:flutter/material.dart';

class MinutePickerScreen extends StatefulWidget {
  final int initialMinutes;

  const MinutePickerScreen({
    super.key,
    required this.initialMinutes,
  });

  @override
  State<MinutePickerScreen> createState() => _MinutePickerScreenState();
}

class _MinutePickerScreenState extends State<MinutePickerScreen> {
  static const int _maxHours = 5;

  late int _hours;
  late int _minutes;
  late FixedExtentScrollController _hoursController;
  late FixedExtentScrollController _minutesController;

  @override
  void initState() {
    super.initState();
    _hours = (widget.initialMinutes ~/ 60).clamp(0, _maxHours);
    _minutes = widget.initialMinutes % 60;
    _hoursController = FixedExtentScrollController(initialItem: _hours);
    _minutesController = FixedExtentScrollController(initialItem: _minutes);
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _finish() {
    final int totalMinutes = _hours * 60 + _minutes;
    Navigator.of(context).pop<int>(totalMinutes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set duration'),
        centerTitle: true,
      ),
      body: Column(
        children: <Widget>[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const <Widget>[
              Text('Hr'),
              Text('Min'),
            ],
          ),
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: ListWheelScrollView.useDelegate(
                    controller: _hoursController,
                    itemExtent: 40,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (int index) {
                      setState(() {
                        _hours = index;
                      });
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (BuildContext context, int index) {
                        if (index < 0 || index > _maxHours) return null;
                        final bool isSelected = index == _hours;
                        final Color color = isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white70;
                        final double fontSize = isSelected ? 28 : 20;
                        return Center(
                          child: Text(
                            index.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: ListWheelScrollView.useDelegate(
                    controller: _minutesController,
                    itemExtent: 40,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (int index) {
                      setState(() {
                        _minutes = index;
                      });
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: 60,
                      builder: (BuildContext context, int index) {
                        final bool isSelected = index == _minutes;
                        final Color color = isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white70;
                        final double fontSize = isSelected ? 28 : 20;
                        return Center(
                          child: Text(
                            index.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: _finish,
        child: const Icon(Icons.check),
      ),
    );
  }
}

