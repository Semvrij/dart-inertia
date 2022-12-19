import 'dart:io';
import 'dart:convert';

import 'package:inertia/inertia.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

const port = 3000;

final uri = Uri.parse('http://${InternetAddress.loopbackIPv4.host}:$port');

void main() {
  group('Server', () {
    HttpServer? server;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    });

    tearDown(() async {
      await server?.close(force: true);
    });

    test('Inertia first page load', () async {
      server?.listen((HttpRequest request) async {
        Inertia(request)
          ..directory = path.join(Directory.current.path, 'example')
          ..render('Index');
      });

      final response = await http.get(uri);

      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers['content-type'], ContentType.html.toString());
      expect(response.body.contains('data-page'), true);
    });

    test('Inertia request', () async {
      server?.listen((HttpRequest request) async {
        Inertia(request)
          ..directory = path.join(Directory.current.path, 'example')
          ..render('Index', {
            'string': 'string',
            'number': 123,
            'boolean': false,
            'list': ['one', 'two', 'three'],
            'map': {'key': 'value'},
            'null': null,
            'callback': () => 'callback',
            'lazy': Inertia.lazy(() => 'lazy'),
            'object': server,
          });
      });

      final response = await http
          .get(uri, headers: {'X-Inertia': 'true', 'X-Inertia-Version': '1'});

      final body = json.decode(response.body) as Map<String, dynamic>;

      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers['content-type'], ContentType.json.toString());
      expect(body['component'], 'Index');
      expect(body['props']['string'], 'string');
      expect(body['props']['number'], 123);
      expect(body['props']['boolean'], false);
      expect(body['props']['list'], ['one', 'two', 'three']);
      expect(body['props']['map'], {'key': 'value'});
      expect(body['props']['null'], null);
      expect(body['props']['callback'], 'callback');
      expect(body['props']['lazy'], null);
      expect(body['props']['object'], server.toString());
    });

    test('Partial reload', () async {
      server?.listen((HttpRequest request) async {
        Inertia(request)
          ..directory = path.join(Directory.current.path, 'example')
          ..render('Index', {
            'string': 'string',
            'number': 123,
            'boolean': false,
            'list': ['one', 'two', 'three'],
            'map': {'key': 'value'},
            'null': null,
            'callback': () => 'callback',
            'lazy': Inertia.lazy(() => 'lazy'),
            'object': server,
          });
      });

      final response = await http.get(uri, headers: {
        'X-Inertia': 'true',
        'X-Inertia-Version': '1',
        'x-inertia-partial-data': 'list,lazy',
        'x-inertia-partial-component': 'Index'
      });

      final body = json.decode(response.body) as Map<String, dynamic>;

      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers['content-type'], ContentType.json.toString());
      expect(body['component'], 'Index');
      expect(body['props']['string'], null);
      expect(body['props']['number'], null);
      expect(body['props']['boolean'], null);
      expect(body['props']['list'], ['one', 'two', 'three']);
      expect(body['props']['map'], null);
      expect(body['props']['null'], null);
      expect(body['props']['callback'], null);
      expect(body['props']['lazy'], 'lazy');
      expect(body['props']['object'], null);
    });

    test('Version', () async {
      const version = '6bd8a01709c8';
      const component = 'Second';

      server?.listen((HttpRequest request) async {
        Inertia(request)
          ..directory = path.join(Directory.current.path, 'example')
          ..version = version
          ..render(component);
      });

      final response = await http.get(uri, headers: {
        'X-Inertia': 'true',
        'X-Inertia-Version': version,
      });

      final body = json.decode(response.body) as Map<String, dynamic>;

      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers['content-type'], ContentType.json.toString());
      expect(body['component'], component);
      expect(body['version'], version);
    });

    test('Shared data', () async {
      server?.listen((HttpRequest request) async {
        Inertia(request)
          ..directory = path.join(Directory.current.path, 'example')
          ..share('shared_data', 'Shared data')
          ..share({'overwritten_prop': 'Not overwritten'})
          ..render(
              'Index', {'prop': 'Prop', 'overwritten_prop': 'Overwritten'});
      });

      final response = await http.get(uri, headers: {
        'X-Inertia': 'true',
        'X-Inertia-Version': '1',
      });

      final body = json.decode(response.body) as Map<String, dynamic>;

      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers['content-type'], ContentType.json.toString());
      expect(body['component'], 'Index');
      expect(body['props']['prop'], 'Prop');
      expect(body['props']['shared_data'], 'Shared data');
      expect(body['props']['overwritten_prop'], 'Overwritten');
    });

    test('External redirect', () async {
      final externalRedirect = Uri.parse('https://example.com');

      server?.listen((HttpRequest request) async {
        Inertia(request).location(externalRedirect);
      });

      final response = await http.get(uri);

      expect(response.statusCode, HttpStatus.conflict);
      expect(
          response.headers['x-inertia-location'], externalRedirect.toString());
    });
  });

  group('Lazy prop', () {
    test('Value', () {
      final lazy = Inertia.lazy(() => 123);

      expect(lazy(), 123);
    });
  });
}
