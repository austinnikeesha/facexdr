import 'dart:io';
import 'package:xml/xml.dart';

void main() {
  final file = File('android/app/src/main/AndroidManifest.xml');
  final content = file.readAsStringSync();
  final document = XmlDocument.parse(content);
  
  for (final application in document.findAllElements('application')) {
    final name = application.getAttribute('android:name');
    print('Application name: $name');
    if (name == 'io.flutter.app.FlutterApplication') {
      print('FOUND v1 embedding!');
    }
  }
  
  for (final metaData in document.findAllElements('meta-data')) {
    final name = metaData.getAttribute('android:name');
    final value = metaData.getAttribute('android:value');
    print('Meta-data: name=$name, value=$value');
    if (name == 'flutterEmbedding') {
      print('FOUND flutterEmbedding = $value');
    }
  }
}