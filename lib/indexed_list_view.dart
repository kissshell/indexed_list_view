library infinite_listview;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// Based upon package infinite_list_view by Simon Lightfoot.
// For more info, see: https://pub.dartlang.org/packages/indexed_list_view

/// Indexed List View
///
/// ListView that lets you jump instantly to any index.
/// Only works for lists with infinite extent.
class IndexedListView extends StatefulWidget {
  /// See [ListView.builder]
  IndexedListView.builder({
    Key? key,
    required this.controller,
    required IndexedWidgetBuilderOrNull itemBuilder,
    this.emptyItemBuilder = defaultEmptyItemBuilder,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.physics,
    this.padding,
    this.itemExtent,
    int? maxItemCount,
    int? minItemCount,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    this.cacheExtent,
  })  : separated = false,
        positiveChildrenDelegate = SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            var _index = index + controller.originIndex;
            if ((minItemCount != null && _index < minItemCount) ||
                (maxItemCount != null && _index > maxItemCount))
              return emptyItemBuilder(context, _index);
            else
              return itemBuilder(context, _index) ?? emptyItemBuilder(context, _index);
          },
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
        ),
        negativeChildrenDelegate = SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            var _index = -1 - index + controller.originIndex;
            if ((minItemCount != null && _index < minItemCount) ||
                (maxItemCount != null && _index > maxItemCount))
              return emptyItemBuilder(context, _index);
            else
              return itemBuilder(context, _index) ?? emptyItemBuilder(context, _index);
          },
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
        ),
        super(key: key);

  /// See [ListView.separated]
  IndexedListView.separated({
    Key? key,
    required this.controller,
    required IndexedWidgetBuilderOrNull itemBuilder,
    required IndexedWidgetBuilderOrNull separatorBuilder,
    this.emptyItemBuilder = defaultEmptyItemBuilder,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.physics,
    this.padding,
    int? maxItemCount,
    int? minItemCount,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    this.cacheExtent,
  })  : separated = true,
        itemExtent = null,
        positiveChildrenDelegate = SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            final _index = (index ~/ 2) + controller.originIndex;
            if ((minItemCount != null && _index < minItemCount) ||
                (maxItemCount != null && _index > maxItemCount))
              return emptyItemBuilder(context, _index);
            else
              return index.isEven
                  ? (itemBuilder(context, _index) ?? emptyItemBuilder(context, _index))
                  : separatorBuilder(context, _index);
          },
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
        ),
        negativeChildrenDelegate = SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            final _index = ((-1 - index) ~/ 2) + controller.originIndex;
            if ((minItemCount != null && _index < minItemCount) ||
                (maxItemCount != null && _index > maxItemCount))
              return emptyItemBuilder(context, _index);
            else
              return index.isOdd
                  ? (itemBuilder(context, _index) ?? emptyItemBuilder(context, _index))
                  : separatorBuilder(context, _index);
          },
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
        ),
        super(key: key);

  static Widget defaultEmptyItemBuilder(BuildContext context, int index) =>
      const SizedBox(width: 5, height: 5);

  final IndexedWidgetBuilderOrNull emptyItemBuilder;

  final bool separated;

  /// See: [ScrollView.scrollDirection]
  final Axis scrollDirection;

  /// See: [ScrollView.reverse]
  final bool reverse;

  /// See: [ScrollView.controller]
  final IndexedScrollController controller;

  /// See: [ScrollView.physics]
  final ScrollPhysics? physics;

  /// See: [BoxScrollView.padding]
  final EdgeInsets? padding;

  /// See: [ListView.itemExtent]
  final double? itemExtent;

  /// See: [ScrollView.cacheExtent]
  final double? cacheExtent;

  /// See: [ListView.childrenDelegate]
  final SliverChildDelegate negativeChildrenDelegate;

  /// See: [ListView.childrenDelegate]
  final SliverChildDelegate positiveChildrenDelegate;

  @override
  _IndexedListViewState createState() => _IndexedListViewState();
}

// -------------------------------------------------------------------------------------------------

/// The builder should create a widget for the given index.
/// When the builder returns `null`, the list will ask the `emptyItemBuilder`
/// to create an "empty" item to be displayed instead.
typedef IndexedWidgetBuilderOrNull = Widget? Function(BuildContext context, int index);

// -------------------------------------------------------------------------------------------------

class _IndexedListViewState extends State<IndexedListView> {
  //
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void didUpdateWidget(IndexedListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> slivers = _buildSlivers(context, negative: false);
    final List<Widget> negativeSlivers = _buildSlivers(context, negative: true);
    final AxisDirection axisDirection = _getDirection(context);
    final scrollPhysics = widget.physics ?? const _AlwaysScrollableScrollPhysics();
    return Scrollable(
      // Rebuild everything when the originIndex changes.
      key: ValueKey(widget.controller.originIndex),
      axisDirection: axisDirection,
      controller: widget.controller,
      physics: scrollPhysics,
      viewportBuilder: (BuildContext context, ViewportOffset offset) {
        return Builder(builder: (BuildContext context) {
          // Build negative [ScrollPosition] for the negative scrolling [Viewport].
          final state = Scrollable.of(context)!;
          final negativeOffset = _IndexedScrollPosition(
            widget.controller,
            physics: scrollPhysics,
            context: state,
            initialPixels: -offset.pixels,
            keepScrollOffset: false,
          );

          // Keep the negative scrolling [Viewport] positioned to the [ScrollPosition].
          offset.addListener(() {
            negativeOffset._forceNegativePixels(offset.pixels);
          });

          /// Stack the two [Viewport]s on top of each other so they move in sync.
          return Stack(
            children: <Widget>[
              Viewport(
                axisDirection: flipAxisDirection(axisDirection),
                anchor: 1.0,
                offset: negativeOffset,
                slivers: negativeSlivers,
                cacheExtent: widget.cacheExtent,
              ),
              Viewport(
                axisDirection: axisDirection,
                offset: offset,
                slivers: slivers,
                cacheExtent: widget.cacheExtent,
              ),
            ],
          );
        });
      },
    );
  }

  AxisDirection _getDirection(BuildContext context) {
    return getAxisDirectionFromAxisReverseAndDirectionality(
        context, widget.scrollDirection, widget.reverse);
  }

  List<Widget> _buildSlivers(BuildContext context, {bool negative = false}) {
    Widget sliver;
    if (widget.itemExtent != null) {
      sliver = SliverFixedExtentList(
        delegate: negative ? widget.negativeChildrenDelegate : widget.positiveChildrenDelegate,
        itemExtent: widget.itemExtent!,
      );
    } else {
      sliver = SliverList(
          delegate: negative ? widget.negativeChildrenDelegate : widget.positiveChildrenDelegate);
    }
    if (widget.padding != null) {
      sliver = SliverPadding(
        padding: negative
            ? widget.padding! - EdgeInsets.only(bottom: widget.padding!.bottom)
            : widget.padding! - EdgeInsets.only(top: widget.padding!.top),
        sliver: sliver,
      );
    }
    return <Widget>[sliver];
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<Axis>('scrollDirection', widget.scrollDirection));
    properties
        .add(FlagProperty('reverse', value: widget.reverse, ifTrue: 'reversed', showName: true));
    properties.add(DiagnosticsProperty<ScrollController>('controller', widget.controller,
        showName: false, defaultValue: null));
    properties.add(DiagnosticsProperty<ScrollPhysics>('physics', widget.physics,
        showName: false, defaultValue: null));
    properties.add(
        DiagnosticsProperty<EdgeInsetsGeometry>('padding', widget.padding, defaultValue: null));
    properties.add(DoubleProperty('itemExtent', widget.itemExtent, defaultValue: null));
    properties.add(DoubleProperty('cacheExtent', widget.cacheExtent, defaultValue: null));
  }
}

// -------------------------------------------------------------------------------------------------

class _AlwaysScrollableScrollPhysics extends ScrollPhysics {
  /// Creates scroll physics that always lets the user scroll.
  const _AlwaysScrollableScrollPhysics({ScrollPhysics? parent}) : super(parent: parent);

  @override
  _AlwaysScrollableScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _AlwaysScrollableScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => true;
}

// -------------------------------------------------------------------------------------------------

/// Sets up a collection of scroll controllers that mirror their movements to
/// each other.
///
/// Controllers are added and returned via [addAndGet]. The initial offset
/// of the newly created controller is synced to the current offset.
/// Controllers must be `dispose`d when no longer in use to prevent memory
/// leaks and performance degradation.
///
/// If controllers are disposed over the course of the lifetime of this
/// object the corresponding scrollables should be given unique keys.
/// Without the keys, Flutter may reuse a controller after it has been disposed,
/// which can cause the controller offsets to fall out of sync.
class IndexedScrollControllerGroup {
  IndexedScrollControllerGroup() {
    _offsetNotifier = _IndexedScrollControllerGroupOffsetNotifier(this);
  }

  final _allControllers = <IndexedScrollController>[];

  late _IndexedScrollControllerGroupOffsetNotifier _offsetNotifier;

  /// The current scroll offset of the group.
  double get offset {
    assert(
    _attachedControllers.isNotEmpty,
    'LinkedScrollControllerGroup does not have any scroll controllers '
        'attached.',
    );
    return _attachedControllers.first.offset;
  }

  double? _initialScrollOffset;

  /// the origin-index changes as the list jumps by index.
  int _originIndex = 0;

  /// Creates a new controller that is linked to any existing ones.
  IndexedScrollController addAndGet() {
    _initialScrollOffset = _attachedControllers.isEmpty
        ? 0.0
        : _attachedControllers.first.position.pixels;
    final controller =
    IndexedScrollController(this, initialScrollOffset: _initialScrollOffset!);
    _allControllers.add(controller);
    // controllerGroup在监听各个controller
    controller.addListener(_offsetNotifier.notifyListeners);
    return controller;
  }

  /// Adds a callback that will be called when the value of [offset] changes.
  void addOffsetChangedListener(VoidCallback onChanged) {
    _offsetNotifier.addListener(onChanged);
  }

  /// Removes the specified offset changed listener.
  void removeOffsetChangedListener(VoidCallback listener) {
    _offsetNotifier.removeListener(listener);
  }

  Iterable<IndexedScrollController> get _attachedControllers =>
      _allControllers.where((controller) => controller.hasClients);

  /// Animates the scroll position of all linked controllers to [offset].
  Future<void> animateTo(
      double offset, {
        required Curve curve,
        required Duration duration,
      }) async {
    final animations = <Future<void>>[];
    for (final controller in _attachedControllers) {
      animations
          .add(controller.animateTo(offset, duration: duration, curve: curve));
    }
    return Future.wait<void>(animations).then<void>((List<void> _) => null);
  }

  /// Jumps the scroll position of all linked controllers to [value].
  void jumpTo(double value) {
    for (final controller in _attachedControllers) {
      controller.jumpTo(value);
    }
  }

  /// Resets the scroll position of all linked controllers to 0.
  void resetScroll() {
    jumpTo(0.0);
  }

  /// Jumps the origin-index to the given [index], and the scroll-position to [offset],
  /// without animation, and without checking if the new value is in range.
  ///
  /// Any active animation is canceled. If the user is currently scrolling, that
  /// action is canceled.
  /// TODO 除了通知当前controller的listener，还要通知peer controller
  void jumpToIndexAndOffset({required int index, required double offset}) {
    // If we didn't change the origin-index, go to its offset position.
    if (_originIndex == index) {
      jumpTo(offset);
    }
    // If we changed the origin, go to its offset position.
    else {
      _originIndex = index;
      _initialScrollOffset = offset;

      // Notify is enough. The key will change,
      // and the offset will revert to _initialScrollOffset),
      for (final controller in _attachedControllers) {
        controller.indexChanged();
      }
    }
  }

  /// Jumps the origin-index to the given [index], and the scroll-position to 0.0,
  /// without animation, and without checking if the new value is in range.
  ///
  /// Any active animation is canceled. If the user is currently scrolling, that
  /// action is canceled.
  void jumpToIndex(int index) {
    jumpToIndexAndOffset(index: index, offset: 0.0);
  }

  /// If the current origin-index is already the same as the given [index],
  /// animates the position from its current value to the [offset] position
  /// relative to the origin-index.
  ///
  /// The returned [Future] will complete when the animation ends, whether it
  /// completed successfully or whether it was interrupted prematurely.
  ///
  /// However, if the current origin-index is different from the given [index],
  /// this will jump to the new index, without any animation.
  Future<void> animateToIndexAndOffset({
    required int index,
    required double offset,
    Duration duration = const Duration(milliseconds: 750),
    Curve curve = Curves.decelerate,
  }) async {
    // If we didn't change origin, go to its 0.0 position.
    if (_originIndex == index) {
      _originIndex = index;
      return animateTo(offset, duration: duration, curve: curve);
    }
    // If we changed the origin, jump to the index and offset.
    else {
      jumpToIndexAndOffset(index: index, offset: offset);
    }
  }

  /// If the current origin-index is already the same as the given [index],
  /// animates the position from its current value to the 0.0 position
  /// relative to the origin-index.
  ///
  /// The returned [Future] will complete when the animation ends, whether it
  /// completed successfully or whether it was interrupted prematurely.
  ///
  /// However, if the current origin-index is different from the given [index],
  /// this will jump to the new position, without any animation.
  Future<void> animateToIndex(
      int index, {
        Duration duration = const Duration(milliseconds: 750),
        Curve curve = Curves.decelerate,
      }) {
    return animateToIndexAndOffset(index: index, offset: 0.0, duration: duration, curve: curve);
  }


  /// Same as [jumpTo] but will keep the current origin-index.
  void jumpToWithSameOriginIndex(double offset) {
    return jumpTo(offset);
  }

  /// Same as [animateTo] but will keep the current origin-index.
  Future<void> animateToWithSameOriginIndex(
      double offset, {
        Duration duration = const Duration(milliseconds: 750),
        Curve curve = Curves.decelerate,
      }) {
    return animateTo(offset, duration: duration, curve: curve);
  }

  /// Same as [jumpTo] but will move [offset] from the current position.
  void jumpToRelative(double offset) {
    return jumpTo(this.offset + offset);
  }

  /// Same as [animateTo] but will move [offset] from the current position.
  Future<void> animateToRelative(
      double offset, {
        Duration duration = const Duration(milliseconds: 750),
        Curve curve = Curves.decelerate,
      }) {
    return animateTo(this.offset + offset, duration: duration, curve: curve);
  }
}

/// This class provides change notification for [LinkedScrollControllerGroup]'s
/// scroll offset.
///
/// This change notifier de-duplicates change events by only firing listeners
/// when the scroll offset of the group has changed.
class _IndexedScrollControllerGroupOffsetNotifier extends ChangeNotifier {
  _IndexedScrollControllerGroupOffsetNotifier(this.controllerGroup);

  final IndexedScrollControllerGroup controllerGroup;

  /// The cached offset for the group.
  ///
  /// This value will be used in determining whether to notify listeners.
  double? _cachedOffset;

  @override
  void notifyListeners() {
    final currentOffset = controllerGroup.offset;
    if (currentOffset != _cachedOffset) {
      _cachedOffset = currentOffset;
      super.notifyListeners();
    }
  }
}
/// Provides scroll with infinite bounds, and keeps a scroll-position and a origin-index.
/// The scroll-position is the number of pixels of scroll, considering the item at origin-index
/// as the origin (0.0). So, for example, if you have scroll-position 10.0 and origin-index 15,
/// then you are 10 pixels after the 15th item.
///
/// Besides regular [ScrollController] methods,
/// offers [IndexedScrollController.jumpToIndex]
/// and [IndexedScrollController.animateToIndex].
///
class IndexedScrollController extends ScrollController {
  final IndexedScrollControllerGroup _controllerGroup;

  final int initialIndex;

  int get originIndex => _controllerGroup._originIndex;

  @override
  double get initialScrollOffset => _controllerGroup._initialScrollOffset ?? super.initialScrollOffset;

  IndexedScrollController(this._controllerGroup, {
    this.initialIndex = 0,
    double initialScrollOffset = 0.0,
    bool keepScrollOffset = true,
    String? debugLabel,
  })  : super(
          initialScrollOffset: initialScrollOffset,
          keepScrollOffset: keepScrollOffset,
          debugLabel: debugLabel,
        );

  @override
  void dispose() {
    _controllerGroup._allControllers.remove(this);
    super.dispose();
  }

  void indexChanged() {
    notifyListeners();
  }

  @override
  void attach(ScrollPosition position) {
    assert(
    position is _IndexedScrollPosition,
    '_LinkedScrollControllers can only be used with'
        ' _IndexedScrollPositions.');
    final _IndexedScrollPosition linkedPosition =
    position as _IndexedScrollPosition;
    assert(linkedPosition.owner == this,
    '_IndexedScrollPosition cannot change controllers once created.');
    super.attach(position);
  }

  @override
  ScrollPosition createScrollPosition(
      ScrollPhysics physics, ScrollContext context, ScrollPosition? oldPosition) {
    return _IndexedScrollPosition(
      this,
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }

  @override
  _IndexedScrollPosition get position => super.position as _IndexedScrollPosition;

  Iterable<IndexedScrollController> get _allPeersWithClients =>
      _controllerGroup._attachedControllers.where((peer) => peer != this);

  bool get canLinkWithPeers => _allPeersWithClients.isNotEmpty;

  Iterable<_IndexedScrollActivity> linkWithPeers(_IndexedScrollPosition driver) {
    assert(canLinkWithPeers);
    return _allPeersWithClients
        .map((peer) => peer.link(driver))
        .expand((e) => e);
  }

  Iterable<_IndexedScrollActivity> link(_IndexedScrollPosition driver) {
    assert(hasClients);
    final activities = <_IndexedScrollActivity>[];
    for (final position in positions) {
      final linkedPosition = position as _IndexedScrollPosition;
      activities.add(linkedPosition.link(driver));
    }
    return activities;
  }
}

// -------------------------------------------------------------------------------------------------

class _IndexedScrollPosition extends ScrollPositionWithSingleContext {
  _IndexedScrollPosition(this.owner, {
    required ScrollPhysics physics,
    required ScrollContext context,
    double initialPixels = 0.0,
    bool keepScrollOffset = true,
    ScrollPosition? oldPosition,
    String? debugLabel,
  }) : super(
          physics: physics,
          context: context,
          initialPixels: initialPixels,
          keepScrollOffset: keepScrollOffset,
          oldPosition: oldPosition,
          debugLabel: debugLabel,
        );

  final IndexedScrollController owner;

  void _forceNegativePixels(double offset) {
    super.forcePixels(-offset);
  }

  @override
  double get minScrollExtent => double.negativeInfinity;

  @override
  double get maxScrollExtent => double.infinity;

  final Set<_IndexedScrollActivity> _peerActivities = <_IndexedScrollActivity>{};

  // We override hold to propagate it to all peer controllers.
  @override
  ScrollHoldController hold(VoidCallback holdCancelCallback) {
    for (final controller in owner._allPeersWithClients) {
      controller.position._holdInternal();
    }
    return super.hold(holdCancelCallback);
  }

  // Calls hold without propagating to peers.
  void _holdInternal() {
    super.hold(() {});
  }

  @override
  void beginActivity(ScrollActivity? newActivity) {
    if (newActivity == null) {
      return;
    }
    for (var activity in _peerActivities) {
      activity.unlink(this);
    }

    _peerActivities.clear();

    super.beginActivity(newActivity);
  }

  @override
  double setPixels(double newPixels) {
    if (newPixels == pixels) {
      return 0.0;
    }
    updateUserScrollDirection(newPixels - pixels > 0.0
        ? ScrollDirection.forward
        : ScrollDirection.reverse);

    if (owner.canLinkWithPeers) {
      _peerActivities.addAll(owner.linkWithPeers(this));
      for (var activity in _peerActivities) {
        activity.moveTo(newPixels);
      }
    }

    return setPixelsInternal(newPixels);
  }

  double setPixelsInternal(double newPixels) {
    return super.setPixels(newPixels);
  }

  @override
  void forcePixels(double value) {
    if (value == pixels) {
      return;
    }
    updateUserScrollDirection(value - pixels > 0.0
        ? ScrollDirection.forward
        : ScrollDirection.reverse);

    if (owner.canLinkWithPeers) {
      _peerActivities.addAll(owner.linkWithPeers(this));
      for (var activity in _peerActivities) {
        activity.jumpTo(value);
      }
    }

    forcePixelsInternal(value);
  }

  void forcePixelsInternal(double value) {
    super.forcePixels(value);
  }

  _IndexedScrollActivity link(_IndexedScrollPosition driver) {
    if (this.activity is! _IndexedScrollActivity) {
      beginActivity(_IndexedScrollActivity(this));
    }
    final _IndexedScrollActivity activity =
    this.activity as _IndexedScrollActivity;
    activity.link(driver);
    return activity;
  }

  void unlink(_IndexedScrollActivity activity) {
    _peerActivities.remove(activity);
  }

  // We override this method to make it public (overridden method is protected)
  @override
  void updateUserScrollDirection(ScrollDirection value) {
    super.updateUserScrollDirection(value);
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('owner: $owner');
  }
}

// -------------------------------------------------------------------------------------------------

class _IndexedScrollActivity extends ScrollActivity {
  _IndexedScrollActivity(_IndexedScrollPosition delegate) : super(delegate);

  @override
  _IndexedScrollPosition get delegate => super.delegate as _IndexedScrollPosition;

  final Set<_IndexedScrollPosition> drivers = <_IndexedScrollPosition>{};

  void link(_IndexedScrollPosition driver) {
    drivers.add(driver);
  }

  void unlink(_IndexedScrollPosition driver) {
    drivers.remove(driver);
    if (drivers.isEmpty) {
      delegate.goIdle();
    }
  }

  @override
  bool get shouldIgnorePointer => true;

  @override
  bool get isScrolling => true;

  // _IndexedScrollActivity is not self-driven but moved by calls to the [moveTo]
  // method.
  @override
  double get velocity => 0.0;

  void moveTo(double newPixels) {
    _updateUserScrollDirection();
    delegate.setPixelsInternal(newPixels);
  }

  void jumpTo(double newPixels) {
    _updateUserScrollDirection();
    delegate.forcePixelsInternal(newPixels);
  }

  void _updateUserScrollDirection() {
    assert(drivers.isNotEmpty);
    ScrollDirection commonDirection = drivers.first.userScrollDirection;
    for (var driver in drivers) {
      if (driver.userScrollDirection != commonDirection) {
        commonDirection = ScrollDirection.idle;
      }
    }
    delegate.updateUserScrollDirection(commonDirection);
  }

  @override
  void dispose() {
    for (var driver in drivers) {
      driver.unlink(this);
    }
    super.dispose();
  }
}
