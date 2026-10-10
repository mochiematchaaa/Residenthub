import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import 'core/core.dart';
import 'screens/admin/admin_screens.dart';
import 'screens/auth/login_screen.dart';
import 'screens/resident/resident_screens.dart';

/// Overall text size. 1.0 is Flutter's default; lower it to make all text smaller.
const double kTextScale = 0.9;

void main() => runApp(const ResidentHubApp());

class ResidentHubApp extends StatelessWidget {
  const ResidentHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final Widget home;
        if (app.role == Role.admin) {
          home = const AdminShell(key: ValueKey('admin'));
        } else if (app.role == Role.resident) {
          home = const ResidentShell(key: ValueKey('resident'));
        } else {
          home = const LoginScreen(key: ValueKey('login'));
        }
        return MaterialApp(
          title: 'ResidentHub',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: app.dark ? ThemeMode.dark : ThemeMode.light,
          // Mouse and trackpad can drag-scroll too (the chip rows and carousels need it on the web).
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad, PointerDeviceKind.stylus},
          ),
          // On a wide screen (the web build on a laptop) show the app inside a phone-sized frame
          // and tell everything inside that the screen really is that size.
          builder: (context, child) {
            final mq0 = MediaQuery.of(context);
            // Keep the text a little smaller than the default, and do not let a large
            // system font size make the screens too big (see kTextScale).
            final sys = mq0.textScaler.scale(1.0).clamp(0.8, 1.0);
            final mq = mq0.copyWith(textScaler: TextScaler.linear(sys * kTextScale));
            if (mq.size.width <= 600) return MediaQuery(data: mq, child: child!);
            final h = math.max(360.0, math.min(mq.size.height - 32, 900.0));
            const w = 430.0;
            return ColoredBox(
              color: app.dark ? const Color(0xFF0B0C14) : const Color(0xFFE3E2F3),
              child: Center(
                child: Container(
                  width: w,
                  height: h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 40, offset: Offset(0, 16))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: MediaQuery(
                      data: mq.copyWith(size: Size(w, h), padding: EdgeInsets.zero, viewPadding: EdgeInsets.zero),
                      child: child!,
                    ),
                  ),
                ),
              ),
            );
          },
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: home,
          ),
        );
      },
    );
  }
}
