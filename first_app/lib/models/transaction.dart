enum TransactionType {
  income,
  deduction,
}

class Transaction {
  final int? id;
  final int payerId;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime date;

  Transaction({
    this.id,
    required this.payerId,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'payer_id': payerId,
      'amount': amount,
      'type': type.toString(),
      'category': category,
      'date': date.toIso8601String(),
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      payerId: map['payer_id'],
      amount: map['amount'],
      type: TransactionType.values.firstWhere(
        (e) => e.toString() == map['type'],
      ),
      category: map['category'],
      date: DateTime.parse(map['date']),
    );
  }
} 