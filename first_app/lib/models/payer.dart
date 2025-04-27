class Payer {
  final int? id;
  final String name;

  Payer({
    this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory Payer.fromMap(Map<String, dynamic> map) {
    return Payer(
      id: map['id'],
      name: map['name'],
    );
  }
} 