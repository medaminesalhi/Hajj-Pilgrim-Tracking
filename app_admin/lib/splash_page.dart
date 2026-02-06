import 'package:flutter/material.dart';

class SplashPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Redirection après 2.5 secondes
    Future.delayed(const Duration(milliseconds: 2500), () {
      Navigator.pushReplacementNamed(context, '/stats');
    });

    return Scaffold(
      backgroundColor: Colors.blue.shade800,
      body: Stack(
        children: [
          // Image Kaaba en header (bannière arrondie)
          Align(
            alignment: Alignment.topCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
              child: Image.asset(
                'assets/images/kaaba.jpg', // Mets l'image dans assets/images/ et déclare dans pubspec.yaml
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo circulaire (par-dessus Kaaba)
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Image.asset(
                      'assets/hajj_logo.png', // Ton logo, transparent de préférence
                      fit: BoxFit.contain,
                      width: 95,
                      height: 95,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  "Bienvenue Mourafiq !",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Montserrat',
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        blurRadius: 5,
                        color: Colors.black26,
                        offset: Offset(1, 2),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "Plateforme de Suivi des Hojjaj Tunisiens",
                  style: TextStyle(
                    color: Colors.blue[100],
                    fontSize: 16,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                // Progress bar stylée
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 4.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
