import 'package:flutter/material.dart';
import '../models/surah.dart';

class SurahTile extends StatelessWidget {
  final Surah surah;
  final VoidCallback onTap;

  const SurahTile({
    super.key,
    required this.surah,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Surah number in a circle
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${surah.id}',
                    style: TextStyle(
                      color: Colors.teal.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Surah details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surah.nameEn,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildChip(
                          surah.originalClassification == 'مكية' ||
                                  surah.originalClassification == 'مدنية'
                              ? surah.originalClassification
                              : (surah.isMakki ? 'Makki' : 'Madani'),
                          surah.isMakki ? Colors.amber : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        _buildChip(
                          '${surah.versesCount} Verses',
                          Colors.blue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arabic name
              Text(
                surah.nameAr,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Indopak',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color.shade800,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
