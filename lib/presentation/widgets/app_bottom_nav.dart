import 'package:flutter/material.dart';

/// Barra de navegação inferior compartilhada entre Home, Mapa e Perfil
/// (US-035 — antes duplicada em `home_screen.dart` e `profile_screen.dart`).
class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (i) {
        if (i == currentIndex) return;
        switch (i) {
          case 0:
            Navigator.pushReplacementNamed(context, '/home');
          case 1:
            Navigator.pushNamed(context, '/map');
          case 2:
            Navigator.pushNamed(context, '/profile');
        }
      },
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined), label: 'Início'),
        BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Mapa'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_outline), label: 'Perfil'),
      ],
    );
  }
}
