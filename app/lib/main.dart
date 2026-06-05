import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'services/results_service.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (_) {
    cameras = [];
  }
  runApp(const ScannerApp());
}

class ScannerApp extends StatelessWidget {
  const ScannerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scanner de Talões',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomePage(results: ResultsService()),
    );
  }
}
