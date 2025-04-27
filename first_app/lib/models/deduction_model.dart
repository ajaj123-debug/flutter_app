class Deduction {
  final String category;
  final double amount;
  final DateTime date;

  Deduction({
    required this.category,
    required this.amount,
    required this.date,
  });

  factory Deduction.fromList(List<dynamic> row) {
    if (row.length < 3) {
      throw Exception(
          'Invalid deduction data format. Expected 3 values but found ${row.length}.');
    }

    // Parse date from string (format: DD/MM/YYYY)
    final dateParts = row[2].toString().split('/');
    if (dateParts.length != 3) {
      throw Exception(
          'Invalid date format. Expected DD/MM/YYYY but found ${row[2]}');
    }

    final date = DateTime(
      int.parse(dateParts[2]), // year
      int.parse(dateParts[1]), // month
      int.parse(dateParts[0]), // day
    );

    return Deduction(
      category: row[0].toString(),
      amount: double.tryParse(row[1].toString()) ?? 0.0,
      date: date,
    );
  }

  // Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  // Create from Map for retrieval
  factory Deduction.fromMap(Map<String, dynamic> map) {
    return Deduction(
      category: map['category'] as String,
      amount: map['amount'] as double,
      date: DateTime.parse(map['date'] as String),
    );
  }
}
