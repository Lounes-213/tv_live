import 'package:flutter/material.dart';

import '../core/platform_info.dart';
import 'router.dart';
import 'theme.dart';

class ClubTiviApp extends StatelessWidget {
  const ClubTiviApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'clubTivi',
      debugShowCheckedModeBanner: false,
      theme: ClubTiviTheme.dark,
      routerConfig: router,
      builder: (context, child) {
        PlatformInfo.detectFromContext(context);
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
