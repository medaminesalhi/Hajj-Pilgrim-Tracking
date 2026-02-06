import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'inscription_page.dart';
import 'session_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Firebase init
  await Firebase.initializeApp();

  // ✅ Recommandé par flutter_foreground_task
  FlutterForegroundTask.initCommunicationPort();

  // ✅ Init Foreground Task (API 8.x)
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'tracking_channel',
      channelName: 'Suivi localisation',
      channelDescription: 'Envoi localisation en arrière-plan',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(15000),
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Hajj – Utilisateur",
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Montserrat',
        scaffoldBackgroundColor: const Color(0xfff3f7fb),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade800,
          elevation: 0,
          titleTextStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
      ),

      // ✅ Ici la session automatique
      home: FutureBuilder(
        future: SessionManager.getUser(),
        builder: (context, snapshot) {
          // Loading
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Aucun utilisateur enregistré
          final user = snapshot.data;
          if (user == null) {
            return const InscriptionPage();
          }

          // Utilisateur déjà enregistré → ouvrir ResumePage directement
          return ResumePage(
            docId: user["docId"]!,
            nom: user["nom"]!,
            prenom: user["prenom"]!,
            passeport: user["docId"]!,
            telephone: user["tel"]!,
            bus: user["bus"]!,
            latitude: 0,
            longitude: 0,
          );
        },
      ),
    );
  }
}
