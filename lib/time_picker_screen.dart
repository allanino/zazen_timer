import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';

class TimePickerScreen extends StatefulWidget {
  final String title;
  final int initialHour;
  final int initialMinute;
  final int initialSecond;

  const TimePickerScreen({
    super.key,
    required this.title,
    required this.initialHour,
    required this.initialMinute,
    required this.initialSecond,
  });

  @override
  State<TimePickerScreen> createState() => _TimePickerScreenState();
}

class _TimePickerScreenState extends State<TimePickerScreen> {
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
  static const double _kPhoneBreakpoint = 360;
  late final List<Widget> _hourWidgets;
  late final List<Widget> _minuteWidgets;
  late final List<Widget> _secondWidgets;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialHour.clamp(0, _hourCount - 1);
    _minute = widget.initialMinute.clamp(0, _minuteCount - 1);
    _second = widget.initialSecond.clamp(0, _secondCount - 1);
    _hourWidgets = List<Widget>.generate(_hourCount, (int index) {
      return Center(
        child: Text(
          index.toString().padLeft(2, '0'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    });
    _minuteWidgets = List<Widget>.generate(_minuteCount, (int index) {
      return Center(
        child: Text(
          index.toString().padLeft(2, '0'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    });
    _secondWidgets = List<Widget>.generate(_secondCount, (int index) {
      return Center(
        child: Text(
          index.toString().padLeft(2, '0'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    });
    _hourController = FixedExtentScrollController(
      initialItem: _loopMultiplier * _hourCount + _hour,
    );
    _minuteController = FixedExtentScrollController(
      initialItem: _loopMultiplier * _minuteCount + _minute,
    );
    _secondController = FixedExtentScrollController(
      initialItem: _loopMultiplier * _secondCount + _second,
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  void _finish() {
    Navigator.of(context).pop<(int, int, int)>((_hour, _minute, _second));
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final bool isPhone = size.width > _kPhoneBreakpoint;
    final double topPadding = isPhone ? size.height * 0.26 : 24;
    final double bottomPadding = isPhone ? size.height * 0.26 : 30;
    final double wheelsTopPadding = isPhone ? 16 : 0;
    final double wheelsBottomPadding = isPhone ? 28 : 12;
    final double selectedFontSize = isPhone ? 30 : 28;
    final double unselectedFontSize = isPhone ? 22 : 20;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            SizedBox(height: topPadding),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(32, wheelsTopPadding, 32, wheelsBottomPadding),
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
                          children: _hourWidgets.asMap().entries.map((e) {
                            final int value = e.key;
                            return Builder(builder: (BuildContext context) {
                              final bool isSelected = value == _hour;
                              final Color color = isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.white70;
                              final double fontSize =
                                  isSelected ? selectedFontSize : unselectedFontSize;
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
                    const SizedBox(
                      width: 12,
                      child: Center(
                        child: Text(
                          ':',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
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
                          children: _minuteWidgets.asMap().entries.map((e) {
                            final int value = e.key;
                            return Builder(builder: (BuildContext context) {
                              final bool isSelected = value == _minute;
                              final Color color = isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.white70;
                              final double fontSize =
                                  isSelected ? selectedFontSize : unselectedFontSize;
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
                    const SizedBox(
                      width: 12,
                      child: Center(
                        child: Text(
                          ':',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
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
                          children: _secondWidgets.asMap().entries.map((e) {
                            final int value = e.key;
                            return Builder(builder: (BuildContext context) {
                              final bool isSelected = value == _second;
                              final Color color = isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.white70;
                              final double fontSize =
                                  isSelected ? selectedFontSize : unselectedFontSize;
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
            Padding(
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: Center(
                child: SizedBox(
                  height: isPhone ? 44 : 32,
                  child: ElevatedButton.icon(
                    onPressed: _finish,
                    icon: const Icon(Icons.check),
                    label: Text(AppLocalizations.of(context)!.confirm),
                    style: ElevatedButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
