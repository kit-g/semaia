part of 'lib.dart';

class _IconButton extends StatelessWidget {
  final void Function()? onPressed;
  final IconData? icon;
  final String? tooltip;

  const _IconButton({
    this.onPressed,
    this.icon,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      visualDensity: const VisualDensity(vertical: -2, horizontal: -3),
    );
  }
}
