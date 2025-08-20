## semaia_api

Semaia API wrapper. Makes network requests and serializes/deserializes data, returning models from
the `semaia_models` package

## Installation

Install the package by listing it in the app's `package.yaml`.

```yaml
dependencies:
  semaia_api:
    path: '<local_path>/semaia_api'
```

or with git:

```yaml
dependencies:
  semaia_api:
    git: '<git_address>'
```

## Usage

Import the package in your Dart file:

```dart
import 'package:semaia_api/semaia_api.dart';

final SqlQueryResult queryResult;
```

## Development

If you write new code, place it in `lib/src` (which makes it private) and then export it
in `lib/semaia_api.dart`:

```dart
export 'src/my_file.dart';
```

## Test

Not maintained for this package
