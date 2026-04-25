import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final input = File('assets/images/arikx_icon_bg_0A0A0A.png');
  final output = File('assets/images/arikx_icon_bg_0A0A0A.png');

  if (!input.existsSync()) {
    stderr.writeln('Missing input file: ${input.path}');
    exitCode = 1;
    return;
  }

  final bytes = input.readAsBytesSync();
  final image = img.decodeWebP(bytes);
  if (image == null) {
    stderr.writeln('Failed to decode WebP logo.');
    exitCode = 1;
    return;
  }

  output.writeAsBytesSync(img.encodePng(image));
  stdout.writeln('Wrote ${output.path}');
}
