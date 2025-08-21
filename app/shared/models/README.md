## semaia_models

A data class and interface package for the Semaia Flutter app. It does not contain any dependencies and should stay that
way.

## Installation

Install the package by listing it in the app's `package.yaml`.

```yaml
dependencies:
  semaia_models:
    path: '<local_path>/semaia_models'
```

or with git:

```yaml
dependencies:
  semaia_models:
    git: '<git_address>'
```

## Usage

Import the package in your Dart file:

```dart
import 'package:semaia_models/semaia_models.dart';

final SqlQueryResult queryResult;
```

## Development

If you write new code, place it in `lib/src` (which makes it private) and then export it in `lib/semaia_models.dart`:

```dart
export 'src/my_file.dart';
```

## Test

Place your unit test files in `/test` and name them `<model>_test.dart`. Write your
tests ([more](https://pub.dev/packages/test)) and run your tests with

```shell
dart test 
```

from the package directory.
