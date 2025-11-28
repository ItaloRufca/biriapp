import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RatingDialog extends StatefulWidget {
  final int? initialRating;

  const RatingDialog({super.key, this.initialRating});

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = (widget.initialRating ?? 3).toDouble();
  }

  String _getEmoji(double value) {
    int rating = value.round();
    switch (rating) {
      case 1:
        return '💩';
      case 2:
        return '👍';
      case 3:
        return '⭐';
      case 4:
        return '⭐⭐';
      case 5:
        return '⭐⭐⭐';
      default:
        return '⭐';
    }
  }

  String _getLabel(double value) {
    int rating = value.round();
    switch (rating) {
      case 1:
        return 'Ruim';
      case 2:
        return 'Legal';
      case 3:
        return 'Bom';
      case 4:
        return 'Ótimo';
      case 5:
        return 'Excelente';
      default:
        return '';
    }
  }

  Color _getColor(double value) {
    int rating = value.round();
    switch (rating) {
      case 1:
        return Colors.brown;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.amber;
      case 4:
        return Colors.orange;
      case 5:
        return const Color(0xFFE94560);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Avaliar Jogo',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Emoji Display
            Text(
              _getEmoji(_currentValue),
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 8),
            Text(
              _getLabel(_currentValue),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _getColor(_currentValue),
              ),
            ),

            const SizedBox(height: 24),

            // Slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _getColor(_currentValue),
                inactiveTrackColor: Colors.grey.shade200,
                thumbColor: _getColor(_currentValue),
                overlayColor: _getColor(_currentValue).withValues(alpha: 0.2),
                trackHeight: 8,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              ),
              child: Slider(
                value: _currentValue,
                min: 1,
                max: 5,
                divisions: 4,
                onChanged: (value) {
                  setState(() {
                    _currentValue = value;
                  });
                },
              ),
            ),

            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.initialRating != null)
                  TextButton(
                    onPressed: () => Navigator.pop(context, 0),
                    child: Text(
                      'Remover',
                      style: GoogleFonts.poppins(color: Colors.red),
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, _currentValue.round());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getColor(_currentValue),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Confirmar',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
