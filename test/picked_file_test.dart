import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_job_manager/core/files/picked_file.dart';

void main() {
  final pdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31]);
  final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);
  final jpg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00]);

  test('a PDF picked through a photo picker is not stored as an image', () {
    expect(nameMatchingContent('oferta.jpg', pdf), 'oferta.pdf');
    expect(nameMatchingContent('blob123', pdf), 'blob123.pdf');
  });

  test('names that already match their content stay untouched', () {
    expect(nameMatchingContent('plan.PDF', pdf), 'plan.PDF');
    expect(nameMatchingContent('a.png', png), 'a.png');
    expect(nameMatchingContent('a.jpeg', jpg), 'a.jpeg');
  });

  test('a photo with the wrong extension gets the right one', () {
    expect(nameMatchingContent('foto.pdf', jpg), 'foto.jpg');
    expect(nameMatchingContent('foto', png), 'foto.png');
  });

  test('unknown content keeps its name', () {
    expect(
      nameMatchingContent('notatki.txt', Uint8List.fromList([1, 2, 3])),
      'notatki.txt',
    );
  });
}
