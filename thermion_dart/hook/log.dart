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
    ..onRecord.listen((record) {
      logFile.writeAsStringSync(
          record.message + "\n",
          mode: FileMode.append,
          flush: true);
      // Tee SEVERE records to stderr so subprocess errors (cl.exe,
      // clang, ld) actually surface to whoever's watching the
      // build. `native_toolchain_c.runProcess` routes captured
      // subprocess stderr through `logger.severe`, but on a
      // failure it then throws a `ProcessException` whose message
      // is just the command + exit code — the real compiler /
      // linker output stays in the build.log file inside the pub
      // cache where CI never sees it. Mirroring SEVERE to stderr
      // makes the actual error visible without affecting
      // successful-build noise (compilers don't emit much stderr
      // on success).
      if (record.level >= Level.SEVERE) {
        stderr.writeln(record.message);
      }
    });
  return logger;
}