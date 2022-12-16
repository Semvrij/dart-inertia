import 'dart:io';
import 'package:inertia/inertia.dart';
import 'package:path/path.dart' as path;

void main() async {
  const routes = {'/': 'Index', '/second': 'Second'};

  final server = await HttpServer.bind(
      InternetAddress.anyIPv6, int.fromEnvironment('PORT', defaultValue: 3000));

  await for (HttpRequest request in server) {
    final Map<String, dynamic> props = {
      'prop': () => DateTime.now(),
      'lazy': Inertia.lazy(() => DateTime.now())
    };

    final String? component = routes[request.uri.path];

    if (component == null) {
      final publicFile = File(path.join(Directory.current.path, 'example',
          'public', request.uri.path.substring(1)));

      if (publicFile.existsSync()) {
        final String data = publicFile.readAsStringSync();

        final Map<String, ContentType> contentTypes = {
          '.json': ContentType.json,
          '.css': ContentType('text', 'css', charset: 'utf-8'),
          '.js': ContentType('text', 'javascript', charset: 'utf-8'),
        };

        request.response.headers.contentType =
            contentTypes[path.extension(request.uri.path)];

        request.response.write(data);

        await request.response.close();

        continue;
      }

      request.response.statusCode = 404;
      request.response.write('404 - Not found');

      await request.response.close();

      continue;
    }

    Inertia(request).render(component, props);
  }
}
