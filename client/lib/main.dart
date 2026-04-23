import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/server_list_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.surface,
  ));
  runApp(const VpsManagerApp());
}

class VpsManagerApp extends StatelessWidget {
  const VpsManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VPS Manager',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      home: const ServerListScreen(),
    );
  }
}
