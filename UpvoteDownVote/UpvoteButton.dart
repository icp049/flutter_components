import 'package:flutter/material.dart';

class UpvoteButton extends StatelessWidget {
  final bool isUpvoted;
  final void Function()? onTap;

  const UpvoteButton({super.key, required this.isUpvoted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        isUpvoted ? Icons.arrow_upward : Icons.arrow_upward_outlined,
        color: isUpvoted ? Colors.blue : Colors.grey,
      ),
    );
  }
}
