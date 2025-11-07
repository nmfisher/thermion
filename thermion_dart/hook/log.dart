import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

Logger createLogger(String packageRoot, String logFilename) {
  var logPath =
      path.join(packageRoot, ".dart_tool", "thermion_dart", "log", logFilename);
  var logFile = File(logPath);
  if (!logFile.parent.existsSync()) {
    logFile.parent.createSync(recursive: true);
  }

  final logger = Logger("")
    ..level = Level.ALL
    ..onRecord.listen((record) => logFile.writeAsStringSync(
        record.message + "\n",
        mode: FileMode.append,
        flush: true));
  return logger;
}