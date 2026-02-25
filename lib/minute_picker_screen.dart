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
  static const int _hourCount = 24;
  static const int _minuteCount = 60;
  static const int _loopMultiplier = 1000;

  late int _hours;
  late int _minutes;
  late FixedExtentScrollController _hoursController;
  late FixedExtentScrollController _minutesController;
  late final List<Widget> _hourWidgets;
  late final List<Widget> _minuteWidgets;

  @override
  void initState() {
    super.initState();
    _hours = (widget.initialMinutes ~/ 60) % _hourCount;
    _minutes = widget.initialMinutes % 60;
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
    // Place initial items in the middle of the looping range so user can scroll both ways
    _hoursController = FixedExtentScrollController(
      initialItem: _loopMultiplier * _hourCount + _hours,
    );
    _minutesController = FixedExtentScrollController(
      initialItem: _loopMultiplier * _minuteCount + _minutes,
    );
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
            child: Padding(
              padding: const EdgeInsets.only(bottom: 56.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: ListWheelScrollView.useDelegate(
                      controller: _hoursController,
                      itemExtent: 40,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (int index) {
                        setState(() {
                          _hours = index % _hourCount;
                        });
                      },
                      childDelegate: ListWheelChildLoopingListDelegate(
                        children: _hourWidgets.map((Widget child) {
                          return Builder(builder: (BuildContext context) {
                            final int value = _hourWidgets.indexOf(child);
                            final bool isSelected = value == _hours;
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
                        }
                        ).toList(),
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
                          _minutes = index % _minuteCount;
                        });
                      },
                      childDelegate: ListWheelChildLoopingListDelegate(
                        children: _minuteWidgets.map((Widget child) {
                          return Builder(builder: (BuildContext context) {
                            final int value = _minuteWidgets.indexOf(child);
                            final bool isSelected = value == _minutes;
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
                        }
                        ).toList(),
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

