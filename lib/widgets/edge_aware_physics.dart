import 'package:flutter/material.dart';

/// Custom physics for the inner ScheduleScreen PageView.
/// At week 1, passes right-swipe outward to parent PageView.
/// At week 20, passes left-swipe outward to parent PageView.
/// In between weeks, normal page-snap behavior.
class EdgeAwarePhysics extends PageScrollPhysics {
  final bool atLeftEdge;
  final bool atRightEdge;

  const EdgeAwarePhysics({
    this.atLeftEdge = false,
    this.atRightEdge = false,
    super.parent,
  });

  @override
  EdgeAwarePhysics applyTo(ScrollPhysics? ancestor) {
    return EdgeAwarePhysics(
      atLeftEdge: atLeftEdge,
      atRightEdge: atRightEdge,
      parent: buildParent(ancestor),
    );
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    // Always accept offset — PageView needs to track the drag
    return true;
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // 左边缘：右滑（负速度）越界时不再回弹，把滑动手势交给外层 PageView。
    if (atLeftEdge &&
        position.pixels <= position.minScrollExtent &&
        velocity < 0) {
      return null;
    }
    // 右边缘：左滑（正速度）越界时不再回弹，把滑动手势交给外层 PageView。
    if (atRightEdge &&
        position.pixels >= position.maxScrollExtent &&
        velocity > 0) {
      return null;
    }
    // 其余情况交给 PageScrollPhysics 正常吸附到整页。
    return super.createBallisticSimulation(position, velocity);
  }
}
