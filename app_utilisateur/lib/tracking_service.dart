import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class TrackingTaskHandler extends TaskHandler {
  String? docId;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Firebase init dans l'isolate background
    await Firebase.initializeApp();

    // ✅ API 8.x : key est un paramètre nommé
    docId = await FlutterForegroundTask.getData<String>(key: 'docId');
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    if (docId == null) return;

    try {
      final pos = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      await FirebaseFirestore.instance.collection('hojjaj').doc(docId!).set({
        "latitude": pos.latitude,
        "longitude": pos.longitude,
        "date": DateTime.now().toIso8601String(),
        "position": GeoPoint(pos.latitude, pos.longitude),
        "lastUpdate": FieldValue.serverTimestamp(),
        "active": true,
      }, SetOptions(merge: true));

      await FlutterForegroundTask.updateService(
        notificationText: "MAJ: ${DateTime.now().toLocal()}",
      );
    } catch (_) {
      // ne pas crash le service
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(TrackingTaskHandler());
}
