import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'tracking_service.dart';
import 'session_manager.dart';

class InscriptionPage extends StatefulWidget {
  const InscriptionPage({super.key});

  @override
  State<InscriptionPage> createState() => _InscriptionPageState();
}

class _InscriptionPageState extends State<InscriptionPage> {
  final _formKey = GlobalKey<FormState>();

  final nomController = TextEditingController();
  final prenomController = TextEditingController();
  final passeportController = TextEditingController();
  final telController = TextEditingController();
  final busController = TextEditingController();

  bool _loading = false;
  String? _erreur;

  @override
  void dispose() {
    nomController.dispose();
    prenomController.dispose();
    passeportController.dispose();
    telController.dispose();
    busController.dispose();
    super.dispose();
  }

  Future<bool> _ensureLocationReady() async {
    final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await geo.Geolocator.openLocationSettings();
      return false;
    }

    var p = await geo.Geolocator.checkPermission();
    if (p == geo.LocationPermission.denied) {
      p = await geo.Geolocator.requestPermission();
      if (p == geo.LocationPermission.denied) return false;
    }
    if (p == geo.LocationPermission.deniedForever) {
      await geo.Geolocator.openAppSettings();
      return false;
    }
    return true;
  }

  Future<void> _soumettreFormulaire() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _erreur = null;
    });

    try {
      final ok = await _ensureLocationReady();
      if (!ok) {
        setState(() => _erreur = "Activez le GPS et autorisez la localisation.");
        return;
      }

      final pos = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final docId = passeportController.text.trim();
      final bus = busController.text.trim();
      final nom = nomController.text.trim();
      final prenom = prenomController.text.trim();
      final tel = telController.text.trim();

      await FirebaseFirestore.instance.collection('hojjaj').doc(docId).set({
        "nom": nom,
        "prenom": prenom,
        "passeport": docId,
        "telephone": tel,
        "bus": bus,
        "latitude": pos.latitude,
        "longitude": pos.longitude,
        "date": DateTime.now().toIso8601String(),
        "position": GeoPoint(pos.latitude, pos.longitude),
        "createdAt": FieldValue.serverTimestamp(),
        "lastUpdate": FieldValue.serverTimestamp(),
        "active": true,
      }, SetOptions(merge: true));

      // ✅ SESSION: on garde l'utilisateur même après fermeture complète
      await SessionManager.saveUser(
        docId: docId,
        nom: nom,
        prenom: prenom,
        tel: tel,
        bus: bus,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResumePage(
            docId: docId,
            nom: nom,
            prenom: prenom,
            passeport: docId,
            telephone: tel,
            bus: bus,
            latitude: pos.latitude,
            longitude: pos.longitude,
          ),
        ),
      );
    } catch (e) {
      setState(() => _erreur = "Erreur : $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  InputDecoration _dec(String label, IconData icon, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inscription Hajj")),
      body: Center(
        child: SingleChildScrollView(
          child: Card(
            elevation: 10,
            margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.all(26.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified_user, color: Colors.blue.shade800),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Bienvenue 👋\nVeuillez remplir vos informations.",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: nomController,
                      decoration: _dec("Nom", Icons.person_outline, hint: "Ex: Ben Ali"),
                      validator: (v) => v == null || v.trim().isEmpty ? "Champ obligatoire" : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: prenomController,
                      decoration: _dec("Prénom", Icons.account_circle_outlined, hint: "Ex: Mohamed"),
                      validator: (v) => v == null || v.trim().isEmpty ? "Champ obligatoire" : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: passeportController,
                      decoration: _dec("Numéro de passeport", Icons.badge_outlined, hint: "Ex: AA123456"),
                      validator: (v) => v == null || v.trim().isEmpty ? "Champ obligatoire" : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: busController,
                      decoration: _dec("Bus (optionnel)", Icons.directions_bus, hint: "Ex: Bus 12"),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: telController,
                      keyboardType: TextInputType.phone,
                      decoration: _dec("Téléphone", Icons.phone_android_rounded, hint: "Ex: +216 ..."),
                      textInputAction: TextInputAction.done,
                    ),

                    const SizedBox(height: 18),

                    if (_erreur != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _erreur!,
                          style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w600),
                        ),
                      ),

                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade800,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          elevation: 2,
                        ),
                        onPressed: _loading ? null : _soumettreFormulaire,
                        icon: _loading
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : const Icon(Icons.check_circle_outline, color: Colors.white),
                        label: Text(_loading ? "Synchronisation..." : "Valider & Continuer"),
                      ),
                    ),

                    const SizedBox(height: 10),
                    Text(
                      "Vos données restent sur cet appareil (session) jusqu’à déconnexion.",
                      style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ======================= PAGE DE RÉSUMÉ =======================

class ResumePage extends StatefulWidget {
  final String docId;
  final String nom;
  final String prenom;
  final String passeport;
  final String telephone;
  final String bus;
  final double latitude;
  final double longitude;

  const ResumePage({
    super.key,
    required this.docId,
    required this.nom,
    required this.prenom,
    required this.passeport,
    required this.telephone,
    required this.bus,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<ResumePage> createState() => _ResumePageState();
}

class _ResumePageState extends State<ResumePage> {
  bool _tracking = false;
  String _statut = "Suivi arrêté.";

  double? _currentLat;
  double? _currentLng;

  @override
  void initState() {
    super.initState();
    _currentLat = widget.latitude;
    _currentLng = widget.longitude;
  }

  Future<void> _startForegroundTracking() async {
    await FlutterForegroundTask.requestNotificationPermission();
    await FlutterForegroundTask.saveData(key: 'docId', value: widget.docId);

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Suivi actif',
      notificationText: 'Envoi position en arrière-plan',
      callback: startCallback,
    );

    setState(() {
      _tracking = true;
      _statut = "Suivi en arrière-plan actif.";
    });
  }

  Future<void> _stopForegroundTracking() async {
    await FlutterForegroundTask.stopService();
    setState(() {
      _tracking = false;
      _statut = "Suivi arrêté.";
    });
  }

  Future<void> _logout() async {
    // stop service + clear session
    await FlutterForegroundTask.stopService();
    await SessionManager.clear();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const InscriptionPage()),
          (_) => false,
    );
  }

  Future<void> _openInMaps() async {
    if (_currentLat == null || _currentLng == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$_currentLat,$_currentLng',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _infoTile({required IconData icon, required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(0.06),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.blue.shade800),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill() {
    final color = _tracking ? Colors.green : Colors.red;
    final icon = _tracking ? Icons.play_circle_fill : Icons.pause_circle_filled;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            _tracking ? "Suivi actif" : "Suivi inactif",
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Résumé Hojjaj"),
          actions: [
            IconButton(
              tooltip: "Changer d’utilisateur",
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Changer d’utilisateur ?"),
                    content: const Text(
                      "Cela va arrêter le suivi et supprimer la session sur cet appareil.",
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
                      ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirmer")),
                    ],
                  ),
                );
                if (ok == true) {
                  await _logout();
                }
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(18.0),
          child: ListView(
            children: [
              // Header chic
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade800, Colors.blue.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${widget.nom} ${widget.prenom}",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Passeport: ${widget.passeport}",
                            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _statusPill(),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Info cards
              _infoTile(icon: Icons.badge, title: "Passeport", value: widget.passeport),
              const SizedBox(height: 12),
              _infoTile(
                icon: Icons.directions_bus,
                title: "Bus",
                value: widget.bus.isEmpty ? "-" : widget.bus,
              ),
              const SizedBox(height: 12),
              _infoTile(icon: Icons.phone_android, title: "Téléphone", value: widget.telephone),

              const SizedBox(height: 18),

              // Tracking section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                      color: Colors.black.withOpacity(0.06),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.gps_fixed, color: Colors.blue.shade800),
                        const SizedBox(width: 8),
                        const Text(
                          "Suivi en arrière-plan",
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statut,
                      style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 12),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _tracking ? _stopForegroundTracking : _startForegroundTracking,
                            icon: Icon(_tracking ? Icons.stop : Icons.play_arrow),
                            label: Text(_tracking ? "Arrêter" : "Démarrer"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _tracking ? Colors.red : Colors.green,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: (_currentLat != null && _currentLng != null) ? _openInMaps : null,
                          icon: const Icon(Icons.map),
                          label: const Text("Maps"),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Text(
                      "Le suivi continue même si vous quittez l’application, tant que la notification “Suivi actif” est visible.",
                      style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
