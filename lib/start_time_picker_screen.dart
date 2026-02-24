import 'package:flutter/material.dart';

class StartTimePickerScreen extends StatefulWidget {
  final TimeOfDay initialTime;

  const StartTimePickerScreen({
    super.key,
    required this.initialTime,
  });

  @override
  State<StartTimePickerScreen> createState() => _StartTimePickerScreenState();
}

class _StartTimePickerScreenState extends State<StartTimePickerScreen> {
  late int _hour;
  late int _minute;
  late int _second;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _secondController;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _second = 0;
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
    _secondController = FixedExtentScrollController(initialItem: _second);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  void _finish() {
    // Return seconds of day so caller can compute precise remaining seconds
    final int secondsOfDay = _hour * 3600 + _minute * 60 + _second;
    Navigator.of(context).pop<int>(secondsOfDay);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start time'),
        centerTitle: true,
      ),
      body: Column(
        children: <Widget>[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const <Widget>[
              Text('Hour'),
              Text('Min'),
              Text('Sec'),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 56.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: ListWheelScrollView.useDelegate(
                      controller: _hourController,
                      itemExtent: 40,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (int index) {
                        setState(() {
                          _hour = index;
                        });
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 24,
                        builder: (BuildContext context, int index) {
                          final bool isSelected = index == _hour;
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
                      controller: _minuteController,
                      itemExtent: 40,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (int index) {
                        setState(() {
                          _minute = index;
                        });
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 60,
                        builder: (BuildContext context, int index) {
                          final bool isSelected = index == _minute;
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
                      controller: _secondController,
                      itemExtent: 40,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (int index) {
                        setState(() {
                          _second = index;
                        });
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 60,
                        builder: (BuildContext context, int index) {
                          final bool isSelected = index == _second;
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

