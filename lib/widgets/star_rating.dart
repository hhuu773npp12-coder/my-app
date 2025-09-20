import 'package:flutter/material.dart';

class StarRating extends StatefulWidget {
  final double initialRating;
  final Function(double) onRatingChanged;
  final bool readOnly;
  final double size;

  const StarRating({
    super.key,
    this.initialRating = 0,
    required this.onRatingChanged,
    this.readOnly = false,
    this.size = 30,
  });

  @override
  State<StarRating> createState() => _StarRatingState();
}

class _StarRatingState extends State<StarRating> {
  late double _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: widget.readOnly ? null : () {
            setState(() {
              _rating = index + 1.0;
            });
            widget.onRatingChanged(_rating);
          },
          child: Icon(
            index < _rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: widget.size,
          ),
        );
      }),
    );
  }
}
