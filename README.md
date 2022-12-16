# Inertia.js Dart Adapter

The Inertia.js server-side adapter for Dart. Visit [inertiajs.com](https://inertiajs.com) to learn more.

## Features

- [x] Inertia responses
- [x] External redirects
- [x] Shared data
- [x] Partial reloads
- [x] Lazy props
- [x] Server Side Rendering
- [ ] Documentation
- [ ] Tests

## Getting started

First, add inertia into your pubspec.yaml.

```yaml
dependencies:
  inertia: ^0.1.0
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
