part of 'lib.dart';

class _DbTreeNode {
  final String name;
  final DbPart? part;

  const _DbTreeNode({
    required this.name,
    this.part,
  });

  @override
  bool operator ==(Object other) {
    if (other is _DbTreeNode) {
      if (other.part case DbPart otherPart) {
        return part == otherPart;
      } else {
        return name == other.name;
      }
    }
    return false;
  }

  @override
  int get hashCode => (part?.name ?? name).hashCode;
}
