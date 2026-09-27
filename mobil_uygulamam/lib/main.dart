import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mobil_uygulamam/screens/home_screen.dart';
import 'package:mobil_uygulamam/services/app_services.dart';
import 'package:mobil_uygulamam/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.create();
  runApp(MyApp(services: services));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.services, this.home = const HomeScreen()});

  final AppServices services;

  /// Testlerde tek bir ekranı açmak için değiştirilebilir.
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: services,
      child: MaterialApp(
        title: 'Mobil Kiler',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        // Tarih seçici gibi hazır bileşenler Türkçe görünsün
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: home,
      ),
    );
  }
}
