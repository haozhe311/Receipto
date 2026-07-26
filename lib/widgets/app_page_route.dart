import 'dart:math' show min;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:receipto/widgets/glass.dart';

/// A page route with an iOS/Xiaomi-style "app-open" transition (fade + scale)
/// that is fully interruptible, plus an interactive left-edge **swipe-to-go-back**
/// gesture that tracks the finger and can reverse mid-flight.
///
/// Drop-in replacement for `MaterialPageRoute` — same `builder`/`settings`/
/// `fullscreenDialog` API. Registered globally is unnecessary: use this at the
/// navigation call sites (`Navigator.push(context, AppPageRoute(builder: ...))`).
class AppPageRoute<T> extends PageRoute<T> {
  AppPageRoute({
    required this.builder,
    super.settings,
    this.maintainStateFlag = true,
    super.fullscreenDialog,
  });

  final WidgetBuilder builder;
  final bool maintainStateFlag;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => maintainStateFlag;

  @override
  bool get opaque => true;

  // A touch longer than the default 300ms for a more graceful glide.
  @override
  Duration get transitionDuration => const Duration(milliseconds: 360);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 320);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // Opaque background so the transition never shows the page underneath.
    return GlassBackground(child: builder(context));
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Incoming page: fade + scale up from 0.92 → 1.0.
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );
    final scaleIn = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    // Page being covered: recede slightly for depth.
    final scaleUnder = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    return ScaleTransition(
      scale: scaleUnder,
      child: FadeTransition(
        opacity: fade,
        child: ScaleTransition(
          scale: scaleIn,
          // The edge-swipe detector lives above the scaled content so its hit
          // area stays put; dragging drives this route's controller directly.
          child: _BackGestureDetector<T>(
            enabledCallback: () => _isPopGestureEnabled,
            onStartPopGesture: _startPopGesture,
            child: child,
          ),
        ),
      ),
    );
  }

  // ── Interactive back-swipe ─────────────────────────────────────────────────

  bool _backGestureInProgress = false;

  /// Whether the left-edge back gesture may start right now.
  bool get _isPopGestureEnabled {
    if (isFirst) return false;
    if (willHandlePopInternally) return false;
    if (fullscreenDialog) return false;
    if (!_backGestureInProgress && controller!.isAnimating) return false;
    if (animation!.status != AnimationStatus.completed) return false;
    if (secondaryAnimation!.status != AnimationStatus.dismissed) return false;
    if (navigator!.userGestureInProgress && !_backGestureInProgress) {
      return false;
    }
    return true;
  }

  _BackGestureController<T> _startPopGesture() {
    _backGestureInProgress = true;
    return _BackGestureController<T>(
      navigator: navigator!,
      controller: controller!,
      onEnded: () => _backGestureInProgress = false,
    );
  }
}

const double _kMinFlingVelocity = 1.0; // screen widths per second
const double _kBackGestureWidth = 24.0;

/// Drives the route's [AnimationController] from a horizontal drag: dragging
/// right lowers the value (revealing the close animation), and on release it
/// either flings the page shut (pop) or snaps it back open.
class _BackGestureController<T> {
  _BackGestureController({
    required this.navigator,
    required this.controller,
    required this.onEnded,
  }) {
    navigator.didStartUserGesture();
  }

  final AnimationController controller;
  final NavigatorState navigator;
  final VoidCallback onEnded;

  void dragUpdate(double delta) {
    controller.value -= delta;
  }

  void dragEnd(double velocity) {
    const Curve animationCurve = Curves.fastLinearToSlowEaseIn;
    final bool animateForward;

    if (velocity.abs() >= _kMinFlingVelocity) {
      animateForward = velocity <= 0;
    } else {
      animateForward = controller.value > 0.5;
    }

    if (animateForward) {
      final int ms =
          min(lerpDouble(320, 0, controller.value)!.floor(), 300);
      controller.animateTo(1.0,
          duration: Duration(milliseconds: ms), curve: animationCurve);
    } else {
      navigator.pop();
      if (controller.isAnimating) {
        final int ms = lerpDouble(0, 320, controller.value)!.floor();
        controller.animateBack(0.0,
            duration: Duration(milliseconds: ms), curve: animationCurve);
      }
    }

    if (controller.isAnimating) {
      late AnimationStatusListener cb;
      cb = (AnimationStatus status) {
        _finish();
        controller.removeStatusListener(cb);
      };
      controller.addStatusListener(cb);
    } else {
      _finish();
    }
  }

  void _finish() {
    navigator.didStopUserGesture();
    onEnded();
  }
}

class _BackGestureDetector<T> extends StatefulWidget {
  const _BackGestureDetector({
    super.key,
    required this.enabledCallback,
    required this.onStartPopGesture,
    required this.child,
  });

  final ValueGetter<bool> enabledCallback;
  final ValueGetter<_BackGestureController<T>> onStartPopGesture;
  final Widget child;

  @override
  State<_BackGestureDetector<T>> createState() =>
      _BackGestureDetectorState<T>();
}

class _BackGestureDetectorState<T> extends State<_BackGestureDetector<T>> {
  _BackGestureController<T>? _controller;
  late HorizontalDragGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = HorizontalDragGestureRecognizer(debugOwner: this)
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd
      ..onCancel = _handleDragCancel;
  }

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _controller = widget.onStartPopGesture();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _controller?.dragUpdate(
        _toLogical(details.primaryDelta! / context.size!.width));
  }

  void _handleDragEnd(DragEndDetails details) {
    _controller?.dragEnd(
        _toLogical(details.velocity.pixelsPerSecond.dx / context.size!.width));
    _controller = null;
  }

  void _handleDragCancel() {
    _controller?.dragEnd(0.0);
    _controller = null;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.enabledCallback()) _recognizer.addPointer(event);
  }

  double _toLogical(double value) {
    return Directionality.of(context) == TextDirection.rtl ? -value : value;
  }

  @override
  Widget build(BuildContext context) {
    final double dragWidth =
        _kBackGestureWidth + MediaQuery.paddingOf(context).left;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        PositionedDirectional(
          start: 0,
          width: dragWidth,
          top: 0,
          bottom: 0,
          child: Listener(
            onPointerDown: _handlePointerDown,
            behavior: HitTestBehavior.translucent,
          ),
        ),
      ],
    );
  }
}
