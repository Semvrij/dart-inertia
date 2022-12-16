import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'lazy_prop.dart';

class Inertia {
  final HttpRequest request;

  String _rootView = 'index';

  final Map<String, dynamic> _sharedProps = {};

  dynamic _version = 1;

  Inertia(this.request) {
    request.response.headers.set('X-Powered-By', 'Dart with package:inertia');

    if (request.response.statusCode == 302 &&
        ['PUT', 'PATCH', 'DELETE'].contains(request.method)) {
      request.response.statusCode = 303;
    }
  }

  void setRootView(String name) {
    _rootView = name;
  }

  void share(key, value) {
    if (key is Map<String, dynamic>) {
      return _sharedProps.addAll(key);
    }

    _sharedProps[key] = value;
  }

  dynamic getShared(String? key, dynamic defaultValue) {
    if (key != null) {
      return _sharedProps[key] ?? defaultValue;
    }

    return _sharedProps;
  }

  void flushShared() {
    _sharedProps.clear();
  }

  void version(Object version) {
    _version = version.toString();
  }

  String getVersion() {
    return _version;
  }

  static LazyProp<dynamic> lazy(LazyPropCallback callback) =>
      LazyProp<dynamic>(callback);

  Future<HttpResponse> render(String component,
      [Map<String, dynamic> props = const <String, dynamic>{}]) async {
    if (request.method == 'GET' &&
        _isInertiaRequest &&
        request.headers.value('x-inertia-version') != 1.toString()) {
      return await location(request.uri);
    }

    _sharedProps.addAll(props);

    final String data = json.encode({
      'version': _version,
      'component': component,
      'props': await _buildProps(_sharedProps, component),
      'url': request.uri.toString()
    });

    if (_isInertiaRequest) {
      request.response.headers.contentType = ContentType.json;
      request.response.headers.set('X-inertia', 'true');
      request.response.headers.set('Vary', 'Accept');

      request.response.write(data);

      return await request.response.close();
    }

    final String fileName = '$_rootView.html';
    final File file =
        File(path.join(path.dirname(Platform.script.path), fileName));

    if (!file.existsSync()) {
      request.response.write('File [$fileName] not found');
      request.response.statusCode;

      return await request.response.close();
    }

    final Map<String, dynamic>? ssr = await _renderSsr(data);

    final String html = file
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

      final File manifest = File(path.join(path.dirname(Platform.script.path),
          'public', 'build', 'manifest.json'));

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

    request.response.headers.contentType = ContentType.html;
    request.response.write(html);

    return await request.response.close();
  }

  location(Uri uri) async {
    request.response.headers.set('X-Inertia-Location', uri.toString());
    request.response.statusCode = 409;

    return await request.response.close();
  }

  bool get _isInertiaRequest => request.headers.value('x-inertia') == 'true';

  List<String> get _partialKeys =>
      request.headers.value('x-inertia-partial-data')?.split(',') ?? <String>[];

  bool _isPartialRender(String component) =>
      _partialKeys.isNotEmpty &&
      request.headers.value('x-inertia-partial-component') == component;

  Object _sanitizeValue(object) {
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
      Map<String, dynamic> props, String component) async {
    final Iterable<String> keys =
        _partialKeys.isEmpty ? props.keys : _partialKeys;

    return <String, dynamic>{
      for (String key in keys)
        if (_isPartialRender(component) && props[key] is LazyProp)
          key: _sanitizeValue(props[key])
        else if (props[key] is! LazyProp)
          key: _sanitizeValue(props[key])
    };
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
