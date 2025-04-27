import '../utils/logger.dart';

class Transaction {
  final String name;
  final double amount;
  final DateTime date;

  Transaction({
    required this.name,
    required this.amount,
    required this.date,
  });

  factory Transaction.fromList(List<dynamic> row) {
    DateTime parseDate(String dateStr) {
      // Try ISO 8601 format first (YYYY-MM-DDTHH:mm:ss.sssZ)
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        // Not ISO format, try DD/MM/YYYY format
        final dateParts = dateStr.split('/');
        if (dateParts.length == 3) {
          final day = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          final year = int.parse(dateParts[2]);
          return DateTime(year, month, day);
        }

        // If all else fails, throw with the original string
        throw FormatException('Invalid date format: $dateStr');
      }
    }

    try {
      final dateStr = row[2].toString();
      return Transaction(
        name: row[0].toString(),
        amount: double.tryParse(row[1].toString()) ?? 0.0,
        date: parseDate(dateStr),
      );
    } catch (e) {
      Logger.error('Error parsing transaction for row: $row', e);
      rethrow;
    }
  }

  // Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  // Create from Map for retrieval
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      name: map['name'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
    );
  }
}
