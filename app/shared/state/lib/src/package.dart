import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

typedef Package = ({String appName, String version, String build});

class PackageProvider with ChangeNotifier {
  late final Package package;

  static PackageProvider of(BuildContext context) {
    return Provider.of<PackageProvider>(context, listen: false);
  }

  static PackageProvider watch(BuildContext context) {
    return Provider.of<PackageProvider>(context, listen: true);
  }

  Future<void> init(Future<Package> Function() initializer) async {
    try {
      package = await initializer();
      notifyListeners();
    } catch (_) {
      //
    }
  }
}
