## pulse_state

PulsQL's state authority and data storage. Relies on [`provider`](https://pub.dev/packages/provider)
to manage state declaratively.

## Installation

Install the package by listing it in the app's `package.yaml`.

```yaml
dependencies:
  pulse_state:
    path: '<local_path>/pulse_state'
```

or with git:

```yaml
dependencies:
  pulse_state:
    git: '<git_address>'
```

## Usage

Import the package in your Dart file:

```dart
import 'package:semaia_state/semaia_state.dart';

final SqlQueryResult queryResult;
```

## Development

If you write new code, place it in `lib/src` (which makes it private) and then export it
in `lib/pulse_state.dart`:

```dart
export 'src/my_file.dart';
```

## Test

Place your unit test files in `/test` and name them `<model>_test.dart`. Write your
tests ([more](https://pub.dev/packages/test)).

Tests rely on [mockito](https://pub.dev/packages/mockito) to generate mocks for the tests.
When editing tests, run

```shell
dart run build_runner build
```

from the package directory.

After that:

```shell
flutter test
```
