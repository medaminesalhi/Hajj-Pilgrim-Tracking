import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'stats_page.dart';         // ta page statistiques (stats_page.dart)
import 'admin_dashboard.dart';   // ta page liste des hojjaj (admin_dashboard.dart)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Admin Hajj",
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Montserrat', // Optionnel si tu veux tout en Montserrat
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoaderToStats(),
        '/dashboard': (context) => AdminDashboard(),
      },
    );
  }
}

// Page intermédiaire qui récupère la position admin AVANT d’ouvrir les stats
class LoaderToStats extends StatefulWidget {
  @override
  State<LoaderToStats> createState() => _LoaderToStatsState();
}

class _LoaderToStatsState extends State<LoaderToStats> {
  String? error;

  @override
  void initState() {
    super.initState();
    _getLocAndGo();
  }

  Future<void> _getLocAndGo() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw Exception("Activez le GPS !");
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever)
        throw Exception("Permission localisation refusée");

      Position adminPosition = await Geolocator.getCurrentPosition();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => StatsPage(), // StatsPage gère sa propre position admin !
        ),
      );
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: Center(
        child: error != null
            ? Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error, color: Colors.red, size: 50),
            SizedBox(height: 15),
            Text(
              "Erreur GPS :\n${error!}",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 18),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text("Réessayer"),
              onPressed: _getLocAndGo,
            )
          ],
        )
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Recherche de la position admin...", style: TextStyle(color: Colors.blueGrey, fontSize: 17)),
          ],
        ),
      ),
    );
  }
}
