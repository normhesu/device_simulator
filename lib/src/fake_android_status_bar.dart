import 'dart:math';
import 'package:flutter/material.dart';

class FakeAndroidStatusBar extends StatelessWidget {
  final double height;
  final double horizontalPadding;
  final Color backgroundColor;

  FakeAndroidStatusBar(
      {this.height, this.horizontalPadding = 8.0, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    const double padding = 2.0;
    const TextStyle style = TextStyle(
      fontFamilyFallback: ['Roboto'],
      fontWeight: FontWeight.w500,
      fontSize: 15.0,
      color: Colors.white,
    );

    final double iconSize = min(height - padding * 2, 22.0);

    final child = Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      height: height,
      color: backgroundColor,
      child: Row(
        children: <Widget>[
          const Text(
            '1:37 PM',
            style: style,
          ),
          Expanded(
            child: Container(),
          ),
          Padding(
            padding: const EdgeInsets.all(padding),
            child: Icon(
              Icons.network_wifi,
              color: Colors.white,
              size: iconSize,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(padding),
            child: Icon(
              Icons.battery_full,
              color: Colors.white,
              size: iconSize,
            ),
          ),
        ],
      ),
    );
    return AbsorbPointer(child: child);
  }
}

class FakeAndroidNavBar extends StatelessWidget {
  final double height;
  final double cornerRadius;

  FakeAndroidNavBar({this.height, this.cornerRadius = 0.0});

  @override
  Widget build(BuildContext context) {
    final child = Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.blueGrey[800],
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(cornerRadius),
          bottomRight: Radius.circular(cornerRadius),
        ),
      ),
      child: Center(
        child: Row(
          children: <Widget>[
            Expanded(
              child: Container(),
            ),
            const Expanded(
              child: RotatedBox(
                quarterTurns: 2,
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.0),
                      ),
                      width: 16.0,
                      height: 16.0,
                    ),
                  ),
                  Center(
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      width: 11.0,
                      height: 11.0,
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Icon(
                Icons.stop,
                color: Colors.white,
              ),
            ),
            Expanded(
              child: Container(),
            ),
          ],
        ),
      ),
    );
    return AbsorbPointer(child: child);
  }
}
