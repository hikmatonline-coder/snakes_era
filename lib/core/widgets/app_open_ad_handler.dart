import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../provider/ads_provider.dart';
import '../../provider/review_provider.dart';

/// Listens for app foreground events and triggers app-open ad logic.
class AppOpenAdHandler extends StatefulWidget {
  const AppOpenAdHandler({super.key, required this.child});

  final Widget child;

  @override
  State<AppOpenAdHandler> createState() => _AppOpenAdHandlerState();
}

class _AppOpenAdHandlerState extends State<AppOpenAdHandler>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final adProvider = context.read<AdProvider>();
        final reviewProvider = context.read<ReviewProvider>();
        adProvider.onAppOpen();
        reviewProvider.onAppOpen(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
