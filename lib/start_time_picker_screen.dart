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
  static const int _hourCount = 24;
  static const int _minuteCount = 60;
  static const int _secondCount = 60;
  static const int _loopMultiplier = 1000;
  late final List<Widget> _hourWidgets;
  late final List<Widget> _minuteWidgets;
  late final List<Widget> _secondWidgets;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _second = 0;
    // Build widget lists for looping delegates
    _hourWidgets = List<Widget>.generate(_hourCount, (int index) {
      return Center(
        child: Text(
          index.toString().padLeft(2, '0'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    });
    _minuteWidgets = List<Widget>.generate(_minuteCount, (int index) {
      return Center(
        child: Text(
          index.toString().padLeft(2, '0'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    });
    _secondWidgets = List<Widget>.generate(_secondCount, (int index) {
      return Center(
        child: Text(
          index.toString().padLeft(2, '0'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    });

    // Place initial items in the middle of the looping range so user can scroll both ways
    _hourController = FixedExtentScrollController(initialItem: _loopMultiplier * _hourCount + _hour);
    _minuteController = FixedExtentScrollController(initialItem: _loopMultiplier * _minuteCount + _minute);
    _secondController = FixedExtentScrollController(initialItem: _loopMultiplier * _secondCount + _second);
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
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
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
                          _hour = index % _hourCount;
                        });
                      },
                      childDelegate: ListWheelChildLoopingListDelegate(
                        children: _hourWidgets.map((Widget child) {
                          return Builder(builder: (BuildContext context) {
                            final int value = _hourWidgets.indexOf(child);
                            final bool isSelected = value == _hour;
                            final Color color = isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white70;
                            final double fontSize = isSelected ? 28 : 20;
                            return Center(
                              child: Text(
                                value.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            );
                          });
                        }).toList(),
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
                          _minute = index % _minuteCount;
                        });
                      },
                      childDelegate: ListWheelChildLoopingListDelegate(
                        children: _minuteWidgets.map((Widget child) {
                          return Builder(builder: (BuildContext context) {
                            final int value = _minuteWidgets.indexOf(child);
                            final bool isSelected = value == _minute;
                            final Color color = isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white70;
                            final double fontSize = isSelected ? 28 : 20;
                            return Center(
                              child: Text(
                                value.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            );
                          });
                        }).toList(),
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
                          _second = index % _secondCount;
                        });
                      },
                      childDelegate: ListWheelChildLoopingListDelegate(
                        children: _secondWidgets.map((Widget child) {
                          return Builder(builder: (BuildContext context) {
                              final int value = _secondWidgets.indexOf(child);
                            final bool isSelected = value == _second;
                            final Color color = isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white70;
                            final double fontSize = isSelected ? 28 : 20;
                            return Center(
                              child: Text(
                                value.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            );
                          });
                        }).toList(),
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

