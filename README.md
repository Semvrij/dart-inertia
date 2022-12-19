# Inertia.js Dart Adapter

The Inertia.js server-side adapter for Dart. Visit [inertiajs.com](https://inertiajs.com) to learn more.

## Features

- Inertia responses
- External redirects
- Shared data
- Partial reloads
- Lazy props
- Server Side Rendering
- Documentation
- Tests

## Getting started

Add inertia to your pubspec.yaml.

```yaml
dependencies:
  inertia: ^0.2.0
```

For a full example, check out the `/example` folder.

```dart
final server = await HttpServer.bind(
    InternetAddress.anyIPv6,
    int.fromEnvironment('PORT', defaultValue: 3000)
);

await for (HttpRequest request in server) {
    Inertia(request).render('Index', {
        'prop': 123
    });
}
```
