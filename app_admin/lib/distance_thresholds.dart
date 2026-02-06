class DistanceThresholds {
  double seuilProche;
  double seuilEloigne;

  // Singleton (une seule instance partout dans l'app)
  static final DistanceThresholds _instance =
  DistanceThresholds._internal();

  factory DistanceThresholds() => _instance;

  DistanceThresholds._internal()
      : seuilProche = 100,
        seuilEloigne = 500;
}
