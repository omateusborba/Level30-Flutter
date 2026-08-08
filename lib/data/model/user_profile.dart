class UserProfile {
  final String name;
  final int totalXp;

  const UserProfile({this.name = 'Estudante', this.totalXp = 0});

  int get level => totalXp ~/ 500 + 1;
  double get xpProgress => (totalXp % 500) / 500.0;
  int get xpInLevel => totalXp % 500;
  int get xpToNextLevel => 500 - xpInLevel;

  String get rankTitle => switch (level) {
    1 => 'Iniciante',
    2 => 'Aprendiz',
    3 => 'Intermediário',
    4 => 'Avançado',
    5 => 'Especialista',
    _ => 'Lendário',
  };

  UserProfile copyWith({String? name, int? totalXp}) =>
      UserProfile(name: name ?? this.name, totalXp: totalXp ?? this.totalXp);

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String,
    totalXp: json['totalXp'] as int,
  );
}
