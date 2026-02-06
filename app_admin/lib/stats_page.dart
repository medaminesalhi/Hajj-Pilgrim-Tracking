import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'distance_thresholds.dart';

class StatsPage extends StatefulWidget {
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  double? adminLat;
  double? adminLng;

  final _procheController = TextEditingController();
  final _eloigneController = TextEditingController();
  bool isLoading = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    _procheController.text =
        DistanceThresholds().seuilProche.toStringAsFixed(0);
    _eloigneController.text =
        DistanceThresholds().seuilEloigne.toStringAsFixed(0);
    _refreshAdminLocation();
  }

  void _refreshAdminLocation() async {
    setState(() {
      isLoading = true;
      error = '';
    });
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        adminLat = position.latitude;
        adminLng = position.longitude;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = "Erreur de localisation : $e";
        isLoading = false;
      });
    }
  }

  void _appliquerSeuils() {
    double proche = double.tryParse(_procheController.text) ?? 100;
    double eloigne = double.tryParse(_eloigneController.text) ?? 500;
    DistanceThresholds().seuilProche = proche;
    DistanceThresholds().seuilEloigne = eloigne;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final seuilProche = DistanceThresholds().seuilProche;
    final seuilEloigne = DistanceThresholds().seuilEloigne;

    return Scaffold(
      backgroundColor: const Color(0xfff3f7fb),
      appBar: AppBar(
        title: const Text("Tableau de bord Mourafiq"),
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Actualiser ma position",
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : _refreshAdminLocation,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
          ? Center(
        child: Text(
          error,
          style: const TextStyle(color: Colors.red),
        ),
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

          // On ignore les hojjaj "masqués" (active == false)
          final activeDocs = docs.where((doc) {
            final data =
            doc.data() as Map<String, dynamic>;
            return data['active'] != false;
          }).toList();

          final int total = activeDocs.length;
          int proches = 0, eloignes = 0, tresEloignes = 0;

          // stats par bus
          final Map<String, int> busCounts = {};

          for (var doc in activeDocs) {
            final data =
            doc.data() as Map<String, dynamic>;

            final double? lat = double.tryParse(
                data['latitude']?.toString() ?? '');
            final double? lng = double.tryParse(
                data['longitude']?.toString() ?? '');
            final String bus =
            (data['bus'] ?? 'Sans bus')
                .toString()
                .trim()
                .isEmpty
                ? 'Sans bus'
                : data['bus'].toString();

            // bus
            busCounts[bus] = (busCounts[bus] ?? 0) + 1;

            if (lat != null &&
                lng != null &&
                adminLat != null &&
                adminLng != null) {
              final double dist =
              Geolocator.distanceBetween(
                  adminLat!, adminLng!, lat, lng);
              if (dist <= seuilProche) {
                proches++;
              } else if (dist <= seuilEloigne) {
                eloignes++;
              } else {
                tresEloignes++;
              }
            }
          }

          return Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16.0, vertical: 22),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: [
                // 🧩 Carte des seuils paramétrables
                Card(
                  margin:
                  const EdgeInsets.only(bottom: 20),
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding:
                    const EdgeInsets.fromLTRB(
                        16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.tune,
                                color: Colors
                                    .blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              "Paramètres de distance",
                              style: TextStyle(
                                fontWeight:
                                FontWeight.w700,
                                fontSize: 16,
                                color: Colors
                                    .blue.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child:
                              _buildThresholdField(
                                label: "Seuil proche",
                                suffix: "m",
                                controller:
                                _procheController,
                                icon: Icons.place_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child:
                              _buildThresholdField(
                                label: "Éloigné",
                                suffix: "m",
                                controller:
                                _eloigneController,
                                icon:
                                Icons.social_distance,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton
                                .styleFrom(
                              backgroundColor: Colors
                                  .blue.shade800,
                              shape:
                              RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius
                                    .circular(12),
                              ),
                              padding:
                              const EdgeInsets
                                  .symmetric(
                                  vertical: 12),
                            ),
                            onPressed: _appliquerSeuils,
                            child: const Text(
                              "Appliquer",
                              style: TextStyle(
                                  fontWeight:
                                  FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 📊 Carte des stats globales
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(20)),
                  child: Padding(
                    padding:
                    const EdgeInsets.symmetric(
                        vertical: 22,
                        horizontal: 16),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.insights,
                                color: Colors
                                    .blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              "Résumé global",
                              style: TextStyle(
                                fontWeight:
                                FontWeight.w700,
                                fontSize: 15,
                                color: Colors
                                    .blue.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Column(
                          children: [
                            Icon(Icons.people,
                                color: Colors
                                    .blue.shade700,
                                size: 38),
                            const SizedBox(height: 4),
                            Text(
                              "$total Hojjaj inscrits",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight:
                                FontWeight.bold,
                                color: Colors
                                    .blue.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment
                              .spaceEvenly,
                          children: [
                            _buildStatColumn(
                              "Proches",
                              proches,
                              Colors.green,
                              seuil: seuilProche,
                            ),
                            Container(
                              width: 1,
                              height: 50,
                              color:
                              Colors.grey.shade200,
                            ),
                            _buildStatColumn(
                              "Éloignés",
                              eloignes,
                              Colors.orange,
                              seuil: seuilEloigne,
                            ),
                            Container(
                              width: 1,
                              height: 50,
                              color:
                              Colors.grey.shade200,
                            ),
                            _buildStatColumn(
                              "Très éloignés",
                              tresEloignes,
                              Colors.red,
                              seuil: null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (busCounts.isNotEmpty)
                          Align(
                            alignment:
                            Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () =>
                                  _showBusStats(
                                    context,
                                    busCounts,
                                    total,
                                  ),
                              icon: const Icon(
                                Icons.directions_bus,
                                size: 18,
                              ),
                              label: const Text(
                                  "Voir statistiques par bus"),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // 🔵 Bouton vers la liste (contenu centré)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      Colors.blue.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(30),
                      ),
                      padding:
                      const EdgeInsets.symmetric(
                          vertical: 18),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(
                          context, '/dashboard');
                    },
                    child: Row(
                      mainAxisSize:
                      MainAxisSize.max,
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.group,
                            size: 24,
                            color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          "Afficher la liste des Hojjaj",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                            FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.chevron_right,
                            color: Colors.white),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildThresholdField({
    required String label,
    required String suffix,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18),
            suffixText: suffix,
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn(
      String title,
      int value,
      Color color, {
        double? seuil,
      }) {
    return Column(
      children: [
        Icon(
          title == "Proches"
              ? Icons.location_on
              : title == "Éloignés"
              ? Icons.warning_amber
              : Icons.error,
          color: color,
          size: 26,
        ),
        const SizedBox(height: 5),
        Text(
          "$value",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        if (seuil != null)
          Text(
            "<${seuil.toInt()} m",
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // 🚌 bottom sheet statistiques par bus
  void _showBusStats(
      BuildContext context,
      Map<String, int> busCounts,
      int total,
      ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final entries = busCounts.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        return Padding(
          padding:
          const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin:
                const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius:
                  BorderRadius.circular(12),
                ),
              ),
              Row(
                children: const [
                  Icon(Icons.directions_bus),
                  SizedBox(width: 8),
                  Text(
                    "Statistiques par bus",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (entries.isEmpty)
                const Text("Aucune donnée de bus."),
              if (entries.isNotEmpty)
                ListView.separated(
                  shrinkWrap: true,
                  physics:
                  const NeverScrollableScrollPhysics(),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) =>
                  const Divider(height: 10),
                  itemBuilder: (_, index) {
                    final e = entries[index];
                    final pct = total == 0
                        ? 0
                        : ((e.value / total) * 100)
                        .round();
                    return Row(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                      children: [
                        Text(
                          e.key,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight:
                              FontWeight.w500),
                        ),
                        Text(
                          "${e.value} (${pct}%)",
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight:
                              FontWeight.w600),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
