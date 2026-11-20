import 'package:flutter/material.dart';

// Tests using pumpAndSettle opt into the same static dock as reduced motion
// users. Dock motion itself is covered with bounded frame pumps.
Widget staticDeskMotion(BuildContext context, Widget? child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(disableAnimations: true),
  child: child!,
);
