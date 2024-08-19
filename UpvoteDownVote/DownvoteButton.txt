import 'package:flutter/material.dart';

class DownvoteButton extends StatelessWidget {
  final bool isDownvoted;
  final void Function()? onTap;

  const DownvoteButton({super.key, required this.isDownvoted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        isDownvoted ? Icons.arrow_downward : Icons.arrow_downward_outlined,
        color: isDownvoted? Colors.red : Colors.grey,
      ),
    );
  }
}
