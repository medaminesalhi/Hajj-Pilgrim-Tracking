import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'distance_thresholds.dart';

class AdminDashboard extends StatefulWidget {
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Position? adminPosition;
  String? error;

  // 🔎 Recherche
  String _searchQuery = '';

  // 🎯 Filtre statut : all / proche / eloigne / tres_eloigne
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _getAdminLocation();
  }

  Future<void> _getAdminLocation() async {
    try {
      setState(() => error = null);
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(
                () => error = "⚠️ Activez le GPS pour calculer les distances.");
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(
                  () => error = "❌ Permission de localisation refusée.");
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(
                () => error = "❌ Permission refusée définitivement.");
        return;
      }
      Position pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        adminPosition = pos;
      });
    } catch (e) {
      setState(() => error = "Erreur localisation admin : $e");
    }
  }

  Color _getColorForDistance(double d) {
    final seuilProche = DistanceThresholds().seuilProche;
    final seuilEloigne = DistanceThresholds().seuilEloigne;
    if (d < seuilProche) return Colors.green;
    if (d < seuilEloigne) return Colors.orange;
    return Colors.red;
  }

  String _getLabelForDistance(double d) {
    final seuilProche = DistanceThresholds().seuilProche;
    final seuilEloigne = DistanceThresholds().seuilEloigne;
    if (d < seuilProche) return "Proche";
    if (d < seuilEloigne) return "Éloigné";
    return "Très éloigné";
  }

  double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  DateTime? _parseLastUpdate(dynamic rawLastUpdate, String rawDate) {
    if (rawLastUpdate is Timestamp) {
      return rawLastUpdate.toDate();
    }
    if (rawLastUpdate is String) {
      final dt = DateTime.tryParse(rawLastUpdate);
      if (dt != null) return dt;
    }
    if (rawDate.isNotEmpty) {
      final dt = DateTime.tryParse(rawDate);
      if (dt != null) return dt;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff3f7fb),
      appBar: AppBar(
        title: const Text(
          "Liste des Hojjaj",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Actualiser la position admin",
            icon: const Icon(Icons.refresh),
            onPressed: _getAdminLocation,
          ),
        ],
      ),
      body: adminPosition == null
          ? Center(
        child: error != null
            ? Text(
          error!,
          style: const TextStyle(
              color: Colors.red, fontSize: 18),
        )
            : const CircularProgressIndicator(),
      )
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('hojjaj')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "Aucun hojjaj trouvé.",
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          // 🔎 + 🎯 Filtrage local
          final filteredDocs = docs.where((doc) {
            final data =
            doc.data() as Map<String, dynamic>;

            // active == false => masqué (anciens)
            final isActive = data['active'] != false;
            if (!isActive) return false;

            final nom =
            (data['nom'] ?? '').toString().toLowerCase();
            final prenom =
            (data['prenom'] ?? '').toString().toLowerCase();
            final telephone = (data['telephone'] ?? '')
                .toString()
                .toLowerCase();
            final bus =
            (data['bus'] ?? '').toString().toLowerCase();

            final search =
            _searchQuery.trim().toLowerCase();

            // Filtre texte (nom / tel / bus)
            final matchesSearch = search.isEmpty ||
                nom.contains(search) ||
                prenom.contains(search) ||
                telephone.contains(search) ||
                bus.contains(search);

            if (!matchesSearch) return false;

            // Filtre statut (Proche / Éloigné / Très éloigné)
            if (_statusFilter == 'all' ||
                adminPosition == null) {
              return true;
            }

            final lat = _parseDouble(data['latitude']);
            final lng = _parseDouble(data['longitude']);
            if (lat == null || lng == null) return false;

            final d = Geolocator.distanceBetween(
              adminPosition!.latitude,
              adminPosition!.longitude,
              lat,
              lng,
            );
            final label = _getLabelForDistance(d);

            switch (_statusFilter) {
              case 'proche':
                return label == 'Proche';
              case 'eloigne':
                return label == 'Éloigné';
              case 'tres_eloigne':
                return label == 'Très éloigné';
              default:
                return true;
            }
          }).toList();

          if (filteredDocs.isEmpty) {
            return const Center(
              child: Text(
                "Aucun hojjaj trouvé.",
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return Column(
            children: [
              _buildSearchAndFilterBar(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, idx) {
                    final doc = filteredDocs[idx];
                    final data = doc.data()
                    as Map<String, dynamic>;
                    final docId = doc.id;

                    final nom = data['nom'] ?? '';
                    final prenom =
                        data['prenom'] ?? '';
                    final passeport =
                        data['passeport'] ?? '';
                    final telephone =
                        data['telephone'] ?? '';
                    final bus = data['bus'] ?? '';
                    final lat =
                    _parseDouble(data['latitude']);
                    final lng =
                    _parseDouble(data['longitude']);
                    final date = data['date'] ?? '';
                    final guideNote =
                        data['guideNote'] ?? '';
                    final rawLastUpdate =
                    data['lastUpdate'];

                    final lastUpdate =
                    _parseLastUpdate(
                        rawLastUpdate, date);

                    final double distance =
                    (lat == null || lng == null)
                        ? 99999
                        : Geolocator.distanceBetween(
                      adminPosition!.latitude,
                      adminPosition!
                          .longitude,
                      lat,
                      lng,
                    ); // mètres

                    final Color couleur =
                    _getColorForDistance(
                        distance);
                    final String statut =
                    _getLabelForDistance(
                        distance);

                    return GestureDetector(
                      onTap: () => _showDetails(
                        context,
                        docId: docId,
                        nom: nom,
                        prenom: prenom,
                        passeport: passeport,
                        telephone: telephone,
                        bus: bus.toString(),
                        lat: lat,
                        lng: lng,
                        date: date,
                        distance: distance,
                        couleur: couleur,
                        guideNote:
                        guideNote.toString(),
                      ),
                      child: Container(
                        margin:
                        const EdgeInsets.only(
                            bottom: 16),
                        decoration: BoxDecoration(
                          borderRadius:
                          BorderRadius
                              .circular(24),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: couleur
                                  .withOpacity(0.08),
                              blurRadius: 17,
                              spreadRadius: 1.3,
                              offset:
                              const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding:
                          const EdgeInsets
                              .symmetric(
                              horizontal: 8.0,
                              vertical: 6.0),
                          child: Column(
                            children: [
                              ListTile(
                                contentPadding:
                                const EdgeInsets
                                    .symmetric(
                                    horizontal:
                                    12,
                                    vertical:
                                    8),
                                leading:
                                CircleAvatar(
                                  backgroundColor:
                                  couleur
                                      .withOpacity(
                                      0.17),
                                  radius: 26,
                                  child: Icon(
                                      Icons.person,
                                      color:
                                      couleur,
                                      size: 32),
                                ),
                                title: Text(
                                  "$nom $prenom",
                                  style:
                                  TextStyle(
                                    fontWeight:
                                    FontWeight
                                        .bold,
                                    fontSize: 19,
                                    color: Colors
                                        .blue
                                        .shade900,
                                    fontFamily:
                                    "Montserrat",
                                    letterSpacing:
                                    0.2,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons
                                              .location_on,
                                          color: Colors
                                              .blue
                                              .shade300,
                                          size: 18,
                                        ),
                                        const SizedBox(
                                            width:
                                            4),
                                        Text(
                                          "${distance.toStringAsFixed(0)} m",
                                          style:
                                          TextStyle(
                                            fontWeight:
                                            FontWeight
                                                .w600,
                                            fontSize:
                                            14,
                                            color: Colors
                                                .blue
                                                .shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (bus !=
                                        null &&
                                        bus
                                            .toString()
                                            .trim()
                                            .isNotEmpty)
                                      Padding(
                                        padding:
                                        const EdgeInsets.only(
                                            top:
                                            2.0),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons
                                                  .directions_bus,
                                              size:
                                              16,
                                              color: Colors
                                                  .orange,
                                            ),
                                            const SizedBox(
                                                width:
                                                4),
                                            Text(
                                              "Bus : ${bus.toString()}",
                                              style: const TextStyle(
                                                  fontSize:
                                                  12,
                                                  color:
                                                  Colors.black87),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                trailing:
                                Container(
                                  decoration:
                                  BoxDecoration(
                                    color: couleur
                                        .withOpacity(
                                        0.15),
                                    borderRadius:
                                    BorderRadius
                                        .circular(
                                        16),
                                  ),
                                  padding:
                                  const EdgeInsets
                                      .symmetric(
                                      horizontal:
                                      12,
                                      vertical:
                                      8),
                                  child: Row(
                                    mainAxisSize:
                                    MainAxisSize
                                        .min,
                                    children: [
                                      Icon(
                                        Icons
                                            .circle,
                                        color:
                                        couleur,
                                        size: 11,
                                      ),
                                      const SizedBox(
                                          width:
                                          6),
                                      Text(
                                        statut,
                                        style:
                                        TextStyle(
                                          fontWeight:
                                          FontWeight
                                              .w700,
                                          color:
                                          couleur,
                                          fontSize:
                                          13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(
                                  height: 4),
                              Row(
                                children: [
                                  TextButton
                                      .icon(
                                    onPressed: () =>
                                        _editGuideNote(
                                          context,
                                          docId:
                                          docId,
                                          currentNote:
                                          guideNote
                                              .toString(),
                                        ),
                                    icon: const Icon(
                                        Icons
                                            .sticky_note_2_outlined,
                                        size:
                                        18),
                                    label: Text(
                                      (guideNote ==
                                          null ||
                                          guideNote
                                              .toString()
                                              .isEmpty)
                                          ? "Ajouter une note"
                                          : "Modifier la note",
                                      style:
                                      const TextStyle(
                                          fontSize:
                                          12),
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip:
                                    "Supprimer ce hojjaj",
                                    icon: const Icon(
                                      Icons
                                          .delete_forever,
                                      color: Colors
                                          .redAccent,
                                    ),
                                    onPressed: () =>
                                        _confirmDelete(
                                          context,
                                          docId,
                                          lastUpdate,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 🔍 Barre de recherche + filtres
  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              hintText:
              "Rechercher par nom, téléphone ou bus",
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip("Tous", "all"),
                _buildFilterChip("Proches", "proche"),
                _buildFilterChip("Éloignés", "eloigne"),
                _buildFilterChip("Très éloignés",
                    "tres_eloigne"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _statusFilter = value;
          });
        },
      ),
    );
  }

  /// 🗑️ Suppression définitive avec règle 24h
  Future<void> _confirmDelete(
      BuildContext context,
      String docId,
      DateTime? lastUpdate,
      ) async {
    final now = DateTime.now();
    if (lastUpdate != null &&
        now.difference(lastUpdate).inHours < 24) {
      // Trop récent : suppression interdite
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Suppression impossible"),
          content: const Text(
              "Ce hojjaj a été mis à jour il y a moins de 24 heures.\n"
                  "Attendez au moins 24h sans mise à jour avant de le supprimer."),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Supprimer ce hojjaj ?"),
        content: const Text(
            "Cette action supprimera définitivement ce hojjaj de Firebase.\n"
                "L'utilisateur ne sera plus visible dans la liste."),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('hojjaj')
            .doc(docId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Hojjaj supprimé.")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    "Erreur lors de la suppression : $e")),
          );
        }
      }
    }
  }

  Future<void> _editGuideNote(
      BuildContext context, {
        required String docId,
        required String currentNote,
      }) async {
    final controller =
    TextEditingController(text: currentNote);
    final newNote = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Note du guide"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText:
            "Info visible seulement pour le guide",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, null),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
                dialogContext,
                controller.text.trim()),
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );

    if (newNote != null) {
      try {
        await FirebaseFirestore.instance
            .collection('hojjaj')
            .doc(docId)
            .update({'guideNote': newNote});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Note mise à jour.")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    "Erreur lors de la mise à jour : $e")),
          );
        }
      }
    }
  }

  void _showDetails(
      BuildContext context, {
        required String docId,
        required String nom,
        required String prenom,
        required String passeport,
        required String telephone,
        required String bus,
        required double? lat,
        required double? lng,
        required String date,
        required double distance,
        required Color couleur,
        required String guideNote,
      }) {
    final String formattedDate =
    date.isNotEmpty && date.length >= 16
        ? date.substring(0, 16)
        : date;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(32)),
      ),
      backgroundColor: Colors.white,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: couleur,
                    child: const Icon(Icons.person,
                        color: Colors.white, size: 29),
                  ),
                  const SizedBox(width: 19),
                  Expanded(
                    child: Text(
                      "$nom $prenom",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 23,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: couleur.withOpacity(0.08),
                      borderRadius:
                      BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.straighten,
                            size: 18, color: couleur),
                        const SizedBox(width: 6),
                        Text(
                          "${distance.toStringAsFixed(0)} m • ${_getLabelForDistance(distance)}",
                          style: TextStyle(
                            color: couleur,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _infoRow(Icons.badge_outlined,
                  Colors.indigo, "Passeport", passeport),
              _infoRow(Icons.phone_android_rounded,
                  Colors.teal, "Téléphone", telephone),
              if (bus.trim().isNotEmpty)
                _infoRow(Icons.directions_bus,
                    Colors.deepOrange, "Bus", bus),
              if (lat != null)
                _infoRow(Icons.location_on,
                    Colors.redAccent, "Latitude",
                    lat.toStringAsFixed(5)),
              if (lng != null)
                _infoRow(Icons.location_on,
                    Colors.redAccent, "Longitude",
                    lng.toStringAsFixed(5)),
              _infoRow(Icons.access_time,
                  Colors.blueGrey, "Dernière maj",
                  formattedDate),
              const SizedBox(height: 10),
              if (guideNote.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                      top: 4.0, bottom: 8.0),
                  child: Text(
                    "📝 Note guide : $guideNote",
                    style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _editGuideNote(
                    context,
                    docId: docId,
                    currentNote: guideNote,
                  ),
                  icon: const Icon(Icons.edit),
                  label: const Text("Modifier la note"),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceAround,
                children: [
                  _buildActionBtn(
                    icon: Icons.phone,
                    color: Colors.green,
                    text: "Appel",
                    onTap: () async {
                      await launchUrl(
                          Uri.parse('tel:$telephone'));
                    },
                  ),
                  _buildActionBtn(
                    icon: Icons.sms,
                    color: Colors.orange,
                    text: "SMS",
                    onTap: () async {
                      await launchUrl(
                          Uri.parse('sms:$telephone'));
                    },
                  ),
                  _buildActionBtn(
                    icon: Icons.chat,
                    color: Colors.teal,
                    text: "WhatsApp",
                    onTap: () async {
                      String whatsappUrl =
                          "https://wa.me/$telephone";
                      await launchUrl(
                        Uri.parse(whatsappUrl),
                        mode: LaunchMode
                            .externalApplication,
                      );
                    },
                  ),
                  _buildActionBtn(
                    icon: Icons.map,
                    color: Colors.blue,
                    text: "Maps",
                    onTap: () async {
                      if (lat != null && lng != null) {
                        String url =
                            "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
                        await launchUrl(
                          Uri.parse(url),
                          mode: LaunchMode
                              .externalApplication,
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.symmetric(
                      vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius:
                    BorderRadius.circular(13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, Color color,
      String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            "$label : ",
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required Color color,
    required String text,
    required Function() onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            radius: 26,
            child: Icon(icon, color: color, size: 30),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color),
        ),
      ],
    );
  }
}
