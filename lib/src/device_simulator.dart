import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'package:custom_navigator/custom_navigator.dart';

import '../device_simulator.dart';
import 'device_specification.dart';
import 'disabled.dart';
import 'fake_android_status_bar.dart';
import 'fake_ios_status_bar.dart';
import 'apple_icon.dart';

enum ToolbarPosition {
  top,
  bottom,
}

const double _kSettingsHeight = 72.0;
final Color _kBackgroundColor = Colors.grey[900];
final Color _kDividerColor = Colors.grey[700];
const _kTextStyle = TextStyle(
  color: Colors.white,
  fontFamilyFallback: ['.SF UI Text', 'Roboto'],
  fontSize: 12.0,
  decoration: TextDecoration.none,
);

class ContentMargin {
  ContentMargin({num top = 0.0, num bottom = 0.0})
      : top = top.toDouble(),
        bottom = bottom.toDouble();
  final double top;
  final double bottom;
}

/// A constant that is true if the application was compiled to run on the web.
///
/// This implementation takes advantage of the fact that JavaScript does not
/// support integers. In this environment, Dart's doubles and ints are
/// backed by the same kind of object. Thus a double `0.0` is identical
/// to an integer `0`. This is not true for Dart code running in AOT or on the
/// VM.
const bool _kIsWeb = identical(0, 0.0);

int _currentDevice = 0;
bool _screenshotMode = false;
TargetPlatform _platform = TargetPlatform.iOS;

/// Add the [DeviceSimulator] at the root of your widget tree, right below your
/// App widget. DeviceSimulator will override the devices [MediaQueryData] and
/// draw simulated device frames for different devices. It will also simulate
/// the iOS or Android status bars (and on Android bottom navigation).
/// You can disable the [DeviceSimulator] by setting the [enable] property to
/// false, this is very much recommended when you are deploying the app.
class DeviceSimulator extends StatefulWidget {
  /// The widget tree that is affected handled by the [DeviceSimulator],
  /// typically this is your whole app except the top [App] widget.
  final Widget child;

  /// Enables or disables the DeviceSimulator, default is enabled, but this
  /// should be set to false in production.
  final bool enable;

  /// The [brightness] decides how to draw the status bar (black or white).
  final Brightness brightness;

  /// The color of the iOS multitasking bar that is available on newer
  /// iOS devices without a home button.
  final Color iOSMultitaskBarColor;

  /// Visibility of the bottom Android navigation bar (default is visible).
  final bool androidShowNavigationBar;

  /// The color of the top Android status bar (default is transparent black).
  final Color androidStatusBarBackgroundColor;

  /// Do not show the note that the screen size is too small.
  final bool silentlyDisableOnSmallDevices;

  /// Width threshold of what is considered a small device width
  ///
  /// screenWidth < [smallDeviceWidth]
  ///
  /// Defaults to [smallDeviceHeight] or `768.0`
  final double smallDeviceWidth;

  /// Height threshold of what is considered a small device height
  ///
  /// screenHeight < [smallDeviceHeight]
  ///
  /// Defaults to [smallDeviceWidth] or `768.0`
  final double smallDeviceHeight;

  /// Set the initial [TargetPlatform]
  ///
  /// Only [TargetPlatform.iOS] and [TargetPlatfrom.android] are currently
  /// supported.
  ///
  /// Explicitly set to `null` to use the [defaultTargetPlatform].
  final TargetPlatform initialPlatform;

  /// A List of [DeviceSpecification]s of the devices to show
  final List<DeviceSpecification> specs;

  /// A flag to enable/disable screenshots button
  final bool enableScreenshots;

  final ToolbarPosition toolbarPosition;

  final ContentMargin contentMargin;

  /// Creates a new [DeviceSimulator].
  DeviceSimulator({
    @required this.child,
    this.enable = true,
    this.brightness = Brightness.light,
    this.iOSMultitaskBarColor = Colors.grey,
    this.androidShowNavigationBar = true,
    this.androidStatusBarBackgroundColor = Colors.black26,
    this.silentlyDisableOnSmallDevices = false,
    this.toolbarPosition = ToolbarPosition.bottom,
    ContentMargin contentMargin,
    double smallDeviceWidth,
    double smallDeviceHeight,
    this.initialPlatform = TargetPlatform.iOS,
    this.specs,
    this.enableScreenshots = true,
  })  : assert(smallDeviceWidth == null || smallDeviceWidth >= 0),
        assert(smallDeviceHeight == null || smallDeviceHeight >= 0),
        assert(
            initialPlatform == null ||
                initialPlatform == TargetPlatform.iOS ||
                initialPlatform == TargetPlatform.android,
            'only iOS and android platforms are supported: $initialPlatform'),
        assert(specs == null || specs.isNotEmpty),
        assert(enableScreenshots != null),
        smallDeviceWidth = smallDeviceWidth ?? smallDeviceHeight ?? 768.0,
        smallDeviceHeight = smallDeviceHeight ?? smallDeviceWidth ?? 768.0,
        contentMargin = contentMargin ?? ContentMargin();

  @override
  _DeviceSimulatorState createState() => _DeviceSimulatorState();
}

class _DeviceSimulatorState extends State<DeviceSimulator> {
  final Key _contentKey = UniqueKey();
  final Key _navigatorKey = GlobalKey<NavigatorState>();
  List<DeviceSpecification> _specs = [];
  bool _hasIosSpecs = false;
  bool _hasAndroidSpecs = false;

  @override
  void initState() {
    super.initState();
    if (widget.enable) SystemChrome.setEnabledSystemUIOverlays([]);
    final initialPlatform = widget.initialPlatform ?? defaultTargetPlatform;
    switch (initialPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        _platform = initialPlatform;
        break;
      default:
    }
    _processSpecs();
  }

  @override
  void didUpdateWidget(DeviceSimulator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.specs != widget.specs) {
      _processSpecs();
    }
  }

  void _processSpecs() {
    // ignore: unnecessary_parenthesis
    _specs = (widget.specs ?? DeviceSpecification.specs);
    _hasIosSpecs = _specs.any((dev) => dev.platform == TargetPlatform.iOS);
    _hasAndroidSpecs =
        _specs.any((dev) => dev.platform == TargetPlatform.android);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enable) return widget.child;

    final noApp = MediaQuery.of(context, nullOk: true) == null;
    if (noApp) {
      return Material(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: _MediaQueryFromWindow(
            child: Builder(builder: _build),
          ),
        ),
      );
    }

    return _build(context);
  }

  Widget _build(BuildContext context) {
    final mq = MediaQuery.of(context);
    //final theme = Theme.of(context);

    if (mq.size.width < widget.smallDeviceWidth ||
        mq.size.height < widget.smallDeviceHeight) {
      if (widget.silentlyDisableOnSmallDevices) {
        return widget.child;
      }
      return DisabledDeviceSimulator(
        child: widget.child,
        style: _kTextStyle,
      );
    }

    final specs =
        _specs.where((device) => device.platform == _platform).toList();
    final spec = specs[_currentDevice];

    Size simulatedSize = spec.size;
    if (mq.orientation == Orientation.landscape)
      simulatedSize = simulatedSize.flipped;

    double navBarHeight = 0.0;
    if (_platform == TargetPlatform.android && widget.androidShowNavigationBar)
      navBarHeight = spec.navBarHeight;

    bool overflowWidth = false;
    bool overflowHeight = false;

    if (simulatedSize.width > mq.size.width) {
      simulatedSize = Size(mq.size.width, simulatedSize.height);
      overflowWidth = true;
    }

    final double settingsHeight = _screenshotMode ? 0.0 : _kSettingsHeight;
    if (simulatedSize.height > mq.size.height - settingsHeight) {
      simulatedSize =
          Size(simulatedSize.width, mq.size.height - settingsHeight);
      overflowHeight = true;
    }

    final double cornerRadius = _screenshotMode ? 0.0 : spec.cornerRadius;

    EdgeInsets padding = spec.padding;
    if (mq.orientation == Orientation.landscape &&
        spec.paddingLandscape != null) padding = spec.paddingLandscape;

    final device = SimulatedDevice(
      key: _contentKey,
      size: simulatedSize,
      padding: padding,
      navBarHeight: navBarHeight,
      child: widget.child,
      navigatorKey: _navigatorKey,
    );

    Widget clippedContent = ClipRRect(
      borderRadius: _kIsWeb ? null : BorderRadius.circular(cornerRadius),
      child: device,
    );

    var corners = <Widget>[];
    if (_kIsWeb && cornerRadius > 0) {
      corners = [
        Alignment.topLeft,
        Alignment.topRight,
        Alignment.bottomLeft,
        Alignment.bottomRight
      ].map<Widget>((alignment) {
        return Positioned(
          top: alignment.y == -1 ? 0 : null,
          left: alignment.x == -1 ? 0 : null,
          right: alignment.x == 1 ? 0 : null,
          bottom: alignment.y == 1 ? 0 : null,
          child: _CornerOverlay(
            color: _kBackgroundColor,
            radius: cornerRadius,
            alignment: alignment,
          ),
        );
      }).toList();
    }

    final Size notchSize =
        _screenshotMode ? Size.zero : spec.notchSize ?? Size.zero;
    Widget notch;
    if (mq.orientation == Orientation.landscape) {
      notch = Positioned(
        left: 0.0,
        top: (simulatedSize.height - notchSize.width) / 2.0,
        width: notchSize.height,
        height: notchSize.width,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(notchSize.height / 2.0),
              bottomRight: Radius.circular(notchSize.height / 2.0),
            ),
            color: _kBackgroundColor,
          ),
        ),
      );
    } else {
      notch = Positioned(
        top: 0.0,
        right: (simulatedSize.width - notchSize.width) / 2.0,
        width: notchSize.width,
        height: notchSize.height,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(notchSize.height / 2.0),
              bottomRight: Radius.circular(notchSize.height / 2.0),
            ),
            color: _kBackgroundColor,
          ),
        ),
      );
    }

    final Widget fakeStatusBar = Positioned(
      left: 0.0,
      right: 0.0,
      height: padding.top,
      child: _platform == TargetPlatform.iOS
          ? FakeIOSStatusBar(
              brightness: widget.brightness,
              height: padding.top,
              notch: spec.notchSize != null,
              roundedCorners: spec.cornerRadius > 0.0,
            )
          : FakeAndroidStatusBar(
              height: padding.top,
              backgroundColor: widget.androidStatusBarBackgroundColor,
            ),
    );

    clippedContent = Stack(
      children: <Widget>[
        clippedContent,
        notch,
        fakeStatusBar,
        if (_platform == TargetPlatform.iOS &&
            spec.cornerRadius > 0.0 &&
            mq.size != simulatedSize)
          Positioned(
            left: 0.0,
            right: 0.0,
            bottom: 0.0,
            height: spec.padding.bottom,
            child: FakeIOSMultitaskBar(
              width: simulatedSize.width / 3.0,
              color: widget.iOSMultitaskBarColor,
              tablet: spec.tablet,
            ),
          ),
        if (widget.androidShowNavigationBar &&
            _platform == TargetPlatform.android)
          Positioned(
            left: 0.0,
            right: 0.0,
            bottom: 0.0,
            height: spec.navBarHeight,
            child: FakeAndroidNavBar(
              height: spec.navBarHeight,
              cornerRadius: cornerRadius,
            ),
          ),
        ...corners,
      ],
    );

    final _toolbar = Container(
      height: _kSettingsHeight,
      color: Colors.black,
      padding: EdgeInsets.only(
          left: 16.0 + mq.padding.left,
          right: 16.0 + mq.padding.right,
          bottom: mq.padding.bottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (_hasAndroidSpecs)
            IconButton(
              icon: Icon(
                Icons.android,
                color: _platform == TargetPlatform.android
                    ? Colors.white
                    : Colors.white24,
                size: 22.0,
              ),
              onPressed: () {
                if (_platform == TargetPlatform.android) {
                  return;
                }
                setState(() {
                  _platform = TargetPlatform.android;
                  _currentDevice = 0;
                });
              },
            ),
          if (_hasIosSpecs)
            IconButton(
              icon: Icon(
                IconApple.apple, // TODO: better image
                color: _platform == TargetPlatform.iOS
                    ? Colors.white
                    : Colors.white24,
                size: 20.0,
              ),
              onPressed: () {
                if (_platform == TargetPlatform.iOS) {
                  return;
                }
                setState(() {
                  _platform = TargetPlatform.iOS;
                  _currentDevice = 0;
                });
              },
            ),
          if (widget.enableScreenshots)
            VerticalDivider(
              color: _kDividerColor,
              indent: 4.0,
            ),
          if (widget.enableScreenshots)
            IconButton(
              icon: const Icon(Icons.camera_alt),
              color: Colors.white,
              onPressed: () {
                setState(() {
                  _screenshotMode = true;
                });
              },
            ),
          VerticalDivider(
            color: _kDividerColor,
            indent: 4.0,
          ),
          Container(
            padding: const EdgeInsets.only(left: 8.0),
            width: 120.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${simulatedSize.width.round()} px',
                      style: _kTextStyle.copyWith(
                          color: overflowWidth ? Colors.orange : null),
                    ),
                    const Text(
                      ' • ',
                      style: _kTextStyle,
                    ),
                    Text(
                      '${simulatedSize.height.round()} px',
                      style: _kTextStyle.copyWith(
                          color: overflowHeight ? Colors.orange : null),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    spec.name,
                    style: _kTextStyle.copyWith(
                        color: Colors.white54, fontSize: 10.0),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                  ),
                ),
              ],
            ),
          ),
          if (specs.length > 1)
            Expanded(
              child: Slider(
                divisions: specs.length - 1,
                min: 0.0,
                max: (specs.length - 1).toDouble(),
                value: _currentDevice.toDouble(),
                label: spec.name,
                onChanged: (double device) {
                  setState(() {
                    _currentDevice = device.round();
                  });
                },
              ),
            ),
        ],
      ),
    );

    final screen = Material(
      color: _kBackgroundColor,
      child: Column(
        children: <Widget>[
          if (!_screenshotMode && widget.toolbarPosition == ToolbarPosition.top)
            _toolbar,
          SizedBox(
            height: widget.contentMargin.top,
          ),
          Expanded(
            child: Align(
              alignment: _screenshotMode ? Alignment.topLeft : Alignment.center,
              child: Container(
                width: simulatedSize.width,
                height: simulatedSize.height,
                child: clippedContent,
              ),
            ),
          ),
          SizedBox(
            height: widget.contentMargin.bottom,
          ),
          if (!_screenshotMode &&
              widget.toolbarPosition == ToolbarPosition.bottom)
            _toolbar,
        ],
      ),
    );

    return GestureDetector(
      behavior: _screenshotMode
          ? HitTestBehavior.opaque
          : HitTestBehavior.deferToChild,
      child: IgnorePointer(
        ignoring: _screenshotMode,
        child: screen,
      ),
      onTap: _screenshotMode
          ? () {
              setState(() {
                _screenshotMode = false;
              });
            }
          : null,
    );
  }
}

/// Builds [MediaQuery] from `window` by listening to [WidgetsBinding].
///
/// It is performed in a standalone widget to rebuild **only** [MediaQuery] and
/// its dependents when `window` changes, instead of rebuilding the entire widget tree.
class _MediaQueryFromWindow extends StatefulWidget {
  const _MediaQueryFromWindow({Key key, this.child}) : super(key: key);

  final Widget child;

  @override
  _MediaQueryFromWindowsState createState() => _MediaQueryFromWindowsState();
}

class _MediaQueryFromWindowsState extends State<_MediaQueryFromWindow>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  // ACCESSIBILITY

  @override
  void didChangeAccessibilityFeatures() {
    setState(() {
      // The properties of window have changed. We use them in our build
      // function, so we need setState(), but we don't cache anything locally.
    });
  }

  // METRICS

  @override
  void didChangeMetrics() {
    setState(() {
      // The properties of window have changed. We use them in our build
      // function, so we need setState(), but we don't cache anything locally.
    });
  }

  @override
  void didChangeTextScaleFactor() {
    setState(() {
      // The textScaleFactor property of window has changed. We reference
      // window in our build function, so we need to call setState(), but
      // we don't need to cache anything locally.
    });
  }

  // RENDERING
  @override
  void didChangePlatformBrightness() {
    setState(() {
      // The platformBrightness property of window has changed. We reference
      // window in our build function, so we need to call setState(), but
      // we don't need to cache anything locally.
    });
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData data =
        MediaQueryData.fromWindow(WidgetsBinding.instance.window);
    if (!kReleaseMode) {
      data = data.copyWith(platformBrightness: debugBrightnessOverride);
    }
    return MediaQuery(
      data: data,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Creates a rounded corner to be used as an overlay, not as a clipper
class _CornerOverlay extends StatelessWidget {
  _CornerOverlay({
    this.color,
    this.radius,
    this.alignment,
  });

  final Color color;
  final double radius;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CornerOverlayPainter(
        color: color,
        radius: radius,
        alignment: alignment,
      ),
      size: Size.square(radius),
    );
  }
}

class _CornerOverlayPainter extends CustomPainter {
  _CornerOverlayPainter({
    this.color,
    this.radius,
    this.alignment,
  });

  final Color color;
  final double radius;
  final Alignment alignment;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..lineTo(size.width, 0.0)
      ..arcToPoint(
        Offset(0.0, size.height),
        radius: Radius.circular(radius),
        clockwise: false,
      )
      ..close();
    if (alignment == Alignment.topRight) {
      canvas.rotate(math.pi / 2);
      canvas.translate(0, -radius);
    } else if (alignment == Alignment.bottomRight) {
      canvas.rotate(math.pi);
      canvas.translate(-radius, -radius);
    } else if (alignment == Alignment.bottomLeft) {
      canvas.rotate(-math.pi / 2);
      canvas.translate(-radius, 0);
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate is _CornerOverlayPainter &&
        (oldDelegate.color != color || oldDelegate.radius != radius);
  }
}

class SimulatedDevice extends StatelessWidget {
  SimulatedDevice({
    Key key,
    @required this.size,
    this.padding = EdgeInsets.zero,
    this.navBarHeight = 0.0,
    @required this.child,
    this.navigatorKey,
  })  : assert(size != null),
        assert(padding != null),
        assert(navBarHeight != null),
        assert(child != null),
        super(key: key);

  factory SimulatedDevice.fromSpec({
    Key key,
    @required DeviceSpecification spec,
    Orientation orientation = Orientation.portrait,
    @required Widget child,
    GlobalKey<NavigatorState> navigatorKey,
    bool androidShowNavigationBar = true,
  }) {
    assert(spec != null);
    assert(orientation != null);
    assert(androidShowNavigationBar != null);
    Size size = spec.size;
    EdgeInsets padding = spec.padding;
    if (orientation == Orientation.landscape) {
      size = size.flipped;
      padding = spec.paddingLandscape ?? padding;
    }
    double navBarHeight = 0.0;
    if (spec.platform == TargetPlatform.android && androidShowNavigationBar) {
      navBarHeight = spec.navBarHeight;
    }
    return SimulatedDevice(
      key: key,
      size: size,
      padding: padding,
      navBarHeight: navBarHeight,
      child: child,
      navigatorKey: navigatorKey,
    );
  }

  final Size size;
  final EdgeInsets padding;
  final double navBarHeight;
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final theme = Theme.of(context);

    final _size = Size(
      math.min(size.width, mq.size.width),
      math.min(size.height - navBarHeight, mq.size.height - navBarHeight),
    );
    final content = MediaQuery(
      data: mq.copyWith(
        size: _size, //Size(size.width, size.height - navBarHeight),
        padding: padding,
      ),
      child: Theme(
        data: theme.copyWith(platform: _platform),
        child: navigatorKey == null
            ? child
            : CustomNavigator(
                navigatorKey: navigatorKey,
                home: child,
                pageRoute: PageRoutes.materialPageRoute,
              ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: navBarHeight),
      child: content,
    );
  }
}
