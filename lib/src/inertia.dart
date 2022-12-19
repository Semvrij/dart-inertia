import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'lazy_prop.dart';

class Inertia {
  final HttpRequest _request;

  /// Sets the root template that's loaded on the first page visit.
  String rootView = 'index';

  /// Shared data will be automatically merged with the page props.
  final Map<String, dynamic> sharedData = {};

  /// To enable automatic asset refreshing, you simply need to tell Inertia what
  /// the current version of your assets is. This can be any [String] `letters,
  /// numbers, or a file hash`, as long as it changes when your assets have been
  /// updated.
  /// In the event that an asset changes, Inertia will automatically make a hard
  /// page visit instead of a normal ajax visit on the next request.
  String version = '1';

  /// Root directory, defaults to [Platform.script]
  String directory = path.dirname(Platform.script.path);

  /// Create an Inertia Request
  Inertia(this._request) {
    _request.response
      ..headers.set('X-Powered-By', 'Dart with package:inertia')
      ..headers.set('Vary', 'X-Inertia');

    if (_request.response.statusCode == HttpStatus.found &&
        ['PUT', 'PATCH', 'DELETE'].contains(_request.method)) {
      _request.response.statusCode = HttpStatus.seeOther;
    }
  }

  /// Shared data will be automatically merged with the page props.
  ///
  /// ```dart
  /// final inertia = Inertia(request);
  ///
  /// inertia.share('key', 'value');
  /// // or
  /// inertia.share({'key': 'value'});
  /// ```
  void share(key, [value]) {
    if (key is Map<String, dynamic>) {
      return sharedData.addAll(key);
    }

    sharedData[key.toString()] = value;
  }

  /// Never included on first visit.
  /// Optionally included on partial reloads.
  /// Only evaluated when needed.
  ///
  /// ```dart
  /// Inertia.lazy(() async => await getArticles());
  /// ```
  static LazyProp<dynamic> lazy(LazyPropCallback callback) =>
      LazyProp<dynamic>(callback);

  /// Provide both the name of the JavaScript page [component], as well as any
  /// [props] for the page.
  /// ```dart
  /// final inertia = Inertia(request);
  ///
  /// inertia.render('Index', {
  ///   name 'test',
  ///   count: 10
  /// });
  /// ```
  void render(String component,
      [Map<String, dynamic> props = const <String, dynamic>{}]) async {
    if (_request.method == 'GET' &&
        _isInertiaRequest &&
        _request.headers.value('x-inertia-version') != version) {
      return location(_request.uri);
    }

    props = {...sharedData, ...props};

    final String data = json.encode({
      'component': component,
      'props': await _buildProps(props, _isPartialRender(component)),
      'url': _request.uri.toString(),
      'version': version
    });

    if (_isInertiaRequest) {
      _request.response
        ..headers.contentType = ContentType.json
        ..headers.set('X-inertia', 'true')
        ..write(data)
        ..close();

      return;
    }

    final String fileName = '$rootView.html';
    final File file = File(path.join(directory, fileName));

    if (!file.existsSync()) {
      _request.response
        ..statusCode = HttpStatus.notFound
        ..write('File [$fileName] not found')
        ..close();

      return;
    }

    final String html = await _parseHtml(file, data);

    _request.response
      ..headers.contentType = ContentType.html
      ..write(html)
      ..close();
  }

  /// Redirect to an external website, or even another non-Inertia endpoint in
  /// your app, within an Inertia request. This is possible using a server-side
  /// initiated window.location visit.
  ///
  /// ```dart
  /// final inertia = Inertia(request);
  ///
  /// inertia.location('https://example.com');
  /// ```
  void location(Uri uri) async {
    _request.response
      ..headers.set('X-Inertia-Location', uri.toString())
      ..statusCode = HttpStatus.conflict
      ..close();
  }

  bool get _isInertiaRequest => _request.headers.value('x-inertia') == 'true';

  List<String> get _partialKeys =>
      _request.headers.value('x-inertia-partial-data')?.split(',') ??
      <String>[];

  bool _isPartialRender(String component) =>
      _partialKeys.isNotEmpty &&
      _request.headers.value('x-inertia-partial-component') == component;

  Object? _sanitizeValue(object) {
    if (object is String ||
        object is num ||
        object is List ||
        object is Map ||
        object is bool ||
        object == null) {
      return object;
    }

    if (object is Function || object is LazyProp) {
      return _sanitizeValue(object());
    }

    return object.toString();
  }

  Future<Map<String, dynamic>> _buildProps(
      Map<String, dynamic> props, bool isPartialRender) async {
    final Iterable<String> keys =
        _partialKeys.isEmpty ? props.keys : _partialKeys;

    return <String, dynamic>{
      for (String key in keys)
        if (isPartialRender && props[key] is LazyProp)
          key: _sanitizeValue(props[key])
        else if (props[key] is! LazyProp)
          key: _sanitizeValue(props[key])
    };
  }

  Future<String> _parseHtml(File file, String data) async {
    final Map<String, dynamic>? ssr = await _renderSsr(data);

    return file
        .readAsStringSync()
        .replaceAllMapped(RegExp("@inertiaHead(?:\\((?:'|\")(.*)(?:'|\")\\))?"),
            (Match match) => ssr?['head'] ?? '')
        .replaceAllMapped(
            RegExp("@inertia(?:\\((?:'|\")(.*)(?:'|\")\\))?"),
            (Match match) => ssr != null
                ? ssr['body']
                : '<div id="${match.group(1) ?? 'app'}" data-page="${data.replaceAll('"', "&quot;").replaceAll("'", "&#039;")}"></div>')
        .replaceAllMapped('@vite', (_) {
      if (const bool.fromEnvironment('APP_DEBUG', defaultValue: false)) {
        return '<script type="module" src="http://localhost:5173/@vite/client"></script><script type="module" src="http://localhost:5173/resources/js/app.js"></script>';
      }

      final File manifest =
          File(path.join(directory, 'public', 'build', 'manifest.json'));

      if (!manifest.existsSync()) {
        return '';
      }

      final Map<String, dynamic> manifestJson =
          json.decode(manifest.readAsStringSync());

      final Map<String, dynamic>? input =
          manifestJson['resources/js/app.js'] as Map<String, dynamic>?;

      final StringBuffer buffer = StringBuffer(input?['file'] != null
          ? '<script type="module" src="/build/${input!['file']}"></script>'
          : '');

      for (final String css in input?['css'] ?? []) {
        buffer.write('<link rel="stylesheet" href="/build/$css" />');
      }

      return buffer.toString();
    });
  }

  Future<Map<String, dynamic>?> _renderSsr(String data) async {
    if (!const bool.fromEnvironment('SSR')) {
      return null;
    }

    try {
      final Map<String, dynamic> response = json.decode((await http.post(
              Uri.parse(const String.fromEnvironment('SSR_URL',
                  defaultValue: 'http://127.0.0.1:13714/render')),
              body: data))
          .body);

      return <String, String>{
        'head': (response['head'] as List).join(''),
        'body': response['body']
      };
    } catch (_) {
      return null;
    }
  }
}
