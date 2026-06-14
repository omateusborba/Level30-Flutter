import 'package:flutter/foundation.dart';
import '../../data/model/user_profile.dart';

class UserProvider extends ChangeNotifier {
  UserProfile _profile = const UserProfile(name: 'Mateus', totalXp: 2350);

  UserProfile get profile => _profile;

  void setName(String name) {
    if (name.trim().isEmpty) return;
    _profile = _profile.copyWith(name: name.trim());
    notifyListeners();
  }

  void addXp(int xp) {
    _profile = _profile.copyWith(totalXp: _profile.totalXp + xp);
    notifyListeners();
  }
}
