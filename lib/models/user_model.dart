class UserModel {
  final String uid;
  final String name;
  final String email;
  final int saldoDummy;
  final bool isParking;
  final String parkedAtSlot;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.saldoDummy,
    required this.isParking,
    required this.parkedAtSlot,
  });

  // Mengubah data JSON/Map dari Firebase menjadi Object Dart
  factory UserModel.fromMap(String uid, Map<dynamic, dynamic> map) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      saldoDummy: map['saldo_dummy'] ?? 0,
      isParking: map['is_parking'] ?? false,
      parkedAtSlot: map['parked_at_slot'] ?? '',
    );
  }

  // Mengubah Object Dart menjadi JSON/Map untuk dikirim ke Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'saldo_dummy': saldoDummy,
      'is_parking': isParking,
      'parked_at_slot': parkedAtSlot,
    };
  }
}