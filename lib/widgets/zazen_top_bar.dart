import 'package:flutter/material.dart';

class ZazenTopBar extends StatelessWidget {
  const ZazenTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Image.asset(
                'assets/images/logo_transparent.png',
                height: 64,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

