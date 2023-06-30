import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rive/rive.dart';

const List<String> playerNames = [
  "Edvard Quickman",
  "Eva Dupree",
  "Abe Lincoln",
  "Ebba Lindgren",
  "Trixxy Liz",
  "Mr. Umbrella",
  "Sir Ocelot",
  "Tinman",
  "Casper Ruud",
];

void main() async {
  // Just setting the locale for date formatting.
  await initializeDateFormatting('en_GB', null);

  runApp(const MyApp());
}

class TennisMatch {
  final String playerA;
  final String playerB;
  final DateTime dateTime;

  TennisMatch(this.playerA, this.playerB, this.dateTime);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF23646D)),
        useMaterial3: true,
      ),
      home: const PullToRefreshPlaygroundPage(),
    );
  }
}

class PullToRefreshPlaygroundPage extends StatefulWidget {
  const PullToRefreshPlaygroundPage({super.key});

  @override
  State<PullToRefreshPlaygroundPage> createState() => _PullToRefreshPlaygroundPageState();
}

class _PullToRefreshPlaygroundPageState extends State<PullToRefreshPlaygroundPage> {
  static const Duration _refreshDuration = Duration(seconds: 3);

  static const String _assetPath = "assets/rive_animations/tennis_pull_to_refresh.riv";
  static const String _stateMachineName = "Tennis Pull to Refresh";
  static const String _pullAmountInputName = "Pull Down";
  static const String _triggerInputName = "Trigger";

  // Tweak this to tweak how much of the vertical height of the animation you need to pull before refreshing
  static const double _animationTriggerAspectRatio = 0.5;

  // Tweak this to tweak how much of the vertical height of the animation you want to show when it's loading
  static const double _indicatorAspectRatio = 0.5;

  StateMachineController? _stateMachineController;
  RiveFile? _riveFile;

  late SMINumber _pullAmountInputHandle;
  late SMITrigger _triggerRefreshInputHandle;

  bool _isRefreshing = false;
  List<TennisMatch>? _loadedMatches;

  @override
  void initState() {
    super.initState();
    _loadedMatches = _generateMatches();
    _loadRiveFile();
  }

  void _loadRiveFile() async {
    // Not handling any loading errors here on purpose since this is a playground app.
    _riveFile = await RiveFile.asset(_assetPath);
    _stateMachineController = _riveFile!.mainArtboard.stateMachineByName(_stateMachineName);
    _pullAmountInputHandle = _stateMachineController!.findSMI<SMINumber>(_pullAmountInputName)!;
    _triggerRefreshInputHandle = _stateMachineController!.findSMI<SMITrigger>(_triggerInputName)!;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Tennis Schedule", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
          backgroundColor: Theme.of(context).primaryColor),
      body: LayoutBuilder(builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              _buildPullToRefreshIndicator(screenWidth: screenWidth),
              _buildHeader(context, _isRefreshing),
              _buildScheduleList(context, _loadedMatches ?? []),
            ]);
      }),
    );
  }

  SliverToBoxAdapter _buildHeader(BuildContext context, bool isRefreshing) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: AnimatedSlide(
        offset: isRefreshing ? const Offset(0, -1) : Offset.zero,
        duration: const Duration(milliseconds: 300),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Pull to refresh",
                style: textTheme.titleMedium!.copyWith(color: colorScheme.onSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _onRefresh() async {
    setState(() {
      _isRefreshing = true;
    });
    // Tell the state machine that we're gonna fire off the trigger animation
    _stateMachineController!.setInputValue(_triggerRefreshInputHandle.id, true);
    await Future.delayed(_refreshDuration);

    setState(() {
      _isRefreshing = false;
      _loadedMatches = _generateMatches();
    });
  }

  Widget _buildPullToRefreshIndicator({required double screenWidth}) {
    final stateMachineController = _stateMachineController;
    final riveFile = _riveFile;

    final triggerPullDistance = _animationTriggerAspectRatio * screenWidth;
    final refreshIndicatorExtent = _indicatorAspectRatio * screenWidth;

    if (riveFile == null || stateMachineController == null) return SliverToBoxAdapter(child: Container());

    // Using cupertino refresh controller because its default behavior is to keep taking up space in the list
    // during refresh, which is what we want for this kind of "full scene" pull to refresh animation.
    return CupertinoSliverRefreshControl(
      onRefresh: _onRefresh,
      refreshTriggerPullDistance: triggerPullDistance,
      refreshIndicatorExtent: refreshIndicatorExtent,
      builder: (context, refreshState, pulledExtent, refreshTriggerPullDistance, refreshIndicatorExtent) {
        final pullPercentage = (pulledExtent / max(1, refreshIndicatorExtent)) * 100;
        stateMachineController.setInputValue(_pullAmountInputHandle.id, pullPercentage);
        return RiveAnimation.direct(
          riveFile,
          controllers: [stateMachineController],
          stateMachines: const [_stateMachineName],
          // We want the animation to fill the width of the container regardless of the height
          fit: BoxFit.fitWidth,
          // Tweak the alignment if you want to have a certain part of the animation stick to the pulled edge.
          alignment: Alignment.center,
        );
      },
    );
  }

  List<TennisMatch> _generateMatches() {
    final matches = <TennisMatch>[];
    final candidates = List<String>.from(playerNames);
    candidates.shuffle();
    while (candidates.length > 2) {
      final playerA = candidates.removeAt(0);
      final playerB = candidates.removeAt(0);
      matches.add(
        TennisMatch(playerA, playerB, DateTime.now().add(Duration(hours: candidates.length))),
      );
    }

    return matches;
  }

  Widget _buildScheduleList(BuildContext context, List<TennisMatch> matches) {
    final dateFormatter = DateFormat.yMMMMd();

    return SliverList.separated(
      itemBuilder: (context, index) {
        final match = matches[index];
        String formattedDate = dateFormatter.format(match.dateTime);
        return ListTile(
          title: Text(
            "${match.playerA} vs. ${match.playerB}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(formattedDate),
        );
      },
      separatorBuilder: (context, index) {
        return const Divider(endIndent: 16,indent: 16);
      },
      itemCount: matches.length,
    );
  }
}
