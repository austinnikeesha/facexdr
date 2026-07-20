import 'dart:io';
import 'package:xml/xml.dart';

void main() {
  var file = File('android/app/src/main/AndroidManifest.xml');
  print('Exists: ${file.existsSync()}');
  var content = file.readAsStringSync();
  print('Content length: ${content.length}');
  var doc = XmlDocument.parse(content);
  for (var app in doc.findAllElements('application')) {
    print('App name: ${app.getAttribute('android:name')}');
    for (var meta in app.findAllElements('meta-data')) {
      print('Meta: ${meta.getAttribute('android:name')} = ${meta.getAttribute('android:value')}');
    }
  }
}