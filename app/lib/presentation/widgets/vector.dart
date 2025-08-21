import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Vector extends StatelessWidget {
  final String asset;
  final double? height;
  final double? width;
  final BoxFit fit;
  final Color? color;
  final BlendMode blend;
  final bool preserveOriginalColor;
  final String? package;

  const Vector(
    this.asset, {
    super.key,
    this.height,
    this.width,
    this.color,
    this.fit = BoxFit.contain,
    this.blend = BlendMode.srcIn,
    this.preserveOriginalColor = false,
    this.package,
  });

  const Vector.ownColor(
    this.asset, {
    super.key,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
    this.blend = BlendMode.srcIn,
    this.package,
  }) : preserveOriginalColor = true,
       color = null;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      // ignore: deprecated_member_use
      color: switch (preserveOriginalColor) {
        true => null,
        false => color ?? Theme.of(context).iconTheme.color,
      },
      // ignore: deprecated_member_use
      colorBlendMode: blend,
      package: package,
    );
  }
}
