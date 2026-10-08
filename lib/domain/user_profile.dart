import 'package:flutter/foundation.dart';

/// Бюджет, который пользователь готов потратить на занятие.
enum Budget {
  free('Бесплатно'),
  low('Недорого'),
  any('Не важно');

  const Budget(this.label);

  final String label;

  static Budget fromName(String? name) =>
      Budget.values.firstWhere((b) => b.name == name, orElse: () => Budget.any);
}

/// Профиль пользователя. Хранится только на устройстве.
@immutable
class UserProfile {
  const UserProfile({
    this.name = '',
    this.city = '',
    this.about = '',
    this.hobbies = const [],
    this.hasCar = false,
    this.budget = Budget.any,
  });

  static const empty = UserProfile();

  final String name;
  final String city;
  final String about;
  final List<String> hobbies;
  final bool hasCar;
  final Budget budget;

  UserProfile copyWith({
    String? name,
    String? city,
    String? about,
    List<String>? hobbies,
    bool? hasCar,
    Budget? budget,
  }) {
    return UserProfile(
      name: name ?? this.name,
      city: city ?? this.city,
      about: about ?? this.about,
      hobbies: hobbies ?? this.hobbies,
      hasCar: hasCar ?? this.hasCar,
      budget: budget ?? this.budget,
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'city': city,
    'about': about,
    'hobbies': hobbies,
    'hasCar': hasCar,
    'budget': budget.name,
  };

  factory UserProfile.fromJson(Map<String, Object?> json) {
    return UserProfile(
      name: json['name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      about: json['about'] as String? ?? '',
      hobbies:
          (json['hobbies'] as List?)?.whereType<String>().toList() ?? const [],
      hasCar: json['hasCar'] as bool? ?? false,
      budget: Budget.fromName(json['budget'] as String?),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.name == name &&
      other.city == city &&
      other.about == about &&
      listEquals(other.hobbies, hobbies) &&
      other.hasCar == hasCar &&
      other.budget == budget;

  @override
  int get hashCode =>
      Object.hash(name, city, about, Object.hashAll(hobbies), hasCar, budget);
}
