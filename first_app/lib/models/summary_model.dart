class Summary {
  final double totalIncome;
  final double totalSavings;
  final double currentMonthSavings;
  final double currentMonthIncome;
  final double totalDeductions;
  final double currentMonthDeductions;
  final double previousMonthSavings;

  Summary({
    required this.totalIncome,
    required this.totalSavings,
    required this.currentMonthSavings,
    required this.currentMonthIncome,
    required this.totalDeductions,
    required this.currentMonthDeductions,
    required this.previousMonthSavings,
  });

  factory Summary.fromList(List<dynamic> row) {
    // Helper function to safely parse double values
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
      return 0.0;
    }

    return Summary(
      totalIncome: parseDouble(row[0]),
      totalSavings: parseDouble(row[1]),
      currentMonthSavings: parseDouble(row[2]),
      currentMonthIncome: parseDouble(row[3]),
      totalDeductions: parseDouble(row[4]),
      currentMonthDeductions: parseDouble(row[5]),
      previousMonthSavings: parseDouble(row[6]),
    );
  }

  // Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'totalIncome': totalIncome,
      'totalSavings': totalSavings,
      'currentMonthSavings': currentMonthSavings,
      'currentMonthIncome': currentMonthIncome,
      'totalDeductions': totalDeductions,
      'currentMonthDeductions': currentMonthDeductions,
      'previousMonthSavings': previousMonthSavings,
    };
  }

  // Create from Map for retrieval
  factory Summary.fromMap(Map<String, dynamic> map) {
    return Summary(
      totalIncome: map['totalIncome']?.toDouble() ?? 0.0,
      totalSavings: map['totalSavings']?.toDouble() ?? 0.0,
      currentMonthSavings: map['currentMonthSavings']?.toDouble() ?? 0.0,
      currentMonthIncome: map['currentMonthIncome']?.toDouble() ?? 0.0,
      totalDeductions: map['totalDeductions']?.toDouble() ?? 0.0,
      currentMonthDeductions: map['currentMonthDeductions']?.toDouble() ?? 0.0,
      previousMonthSavings: map['previousMonthSavings']?.toDouble() ?? 0.0,
    );
  }
}
