import 'package:sqflite/sqflite.dart';

class ImaamSalary {
  final int? id;
  final int year;
  final int month;
  final bool isPaid;
  final DateTime? paidDate;
  final double amount;
  final String? notes;

  ImaamSalary({
    this.id,
    required this.year,
    required this.month,
    required this.isPaid,
    this.paidDate,
    required this.amount,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'year': year,
      'month': month,
      'is_paid': isPaid ? 1 : 0,
      'paid_date': paidDate?.toIso8601String(),
      'amount': amount,
      'notes': notes,
    };
  }

  factory ImaamSalary.fromMap(Map<String, dynamic> map) {
    return ImaamSalary(
      id: map['id'] as int?,
      year: map['year'] as int,
      month: map['month'] as int,
      isPaid: map['is_paid'] == 1,
      paidDate:
          map['paid_date'] != null ? DateTime.parse(map['paid_date']) : null,
      amount: map['amount'] as double,
      notes: map['notes'] as String?,
    );
  }
}
