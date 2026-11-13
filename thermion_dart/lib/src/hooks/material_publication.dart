import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

const materialJournalName = '.thermion-materials.pending.json';
const materialStagingPrefix = '.staging-thermion-materials-';
final _pendingPublications = <String, Future<void>>{};

/// Serialize helper calls in this process and hooks running in other processes.
Future<T> withMaterialOutputLock<T>(Directory output, Future<T> Function() action) async {
  final key = p.normalize(p.absolute(output.path));
  final previous = _pendingPublications[key] ?? Future<void>.value();
  final completion = Completer<void>();
  final current = completion.future;
  _pendingPublications[key] = current;
  await previous;
  try {
    output.createSync(recursive: true);
    final lock = await File(p.join(output.path, '.thermion-materials.lock')).open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.blockingExclusive);
      try {
        return await action();
      } finally {
        await lock.unlock();
      }
    } finally {
      await lock.close();
    }
  } finally {
    completion.complete();
    if (identical(_pendingPublications[key], current)) _pendingPublications.remove(key);
  }
}

/// Restore the previous generation after a process died during publication.
/// Backups are copied, never moved, so interrupted recovery is safe to retry.
void recoverMaterialPublication(Directory output) {
  final journal = File(p.join(output.path, materialJournalName));
  if (journal.existsSync()) {
    final state = jsonDecode(journal.readAsStringSync()) as Map<String, dynamic>;
    final stage = Directory(p.join(output.path, state['staging'] as String));
    final existing = (state['existing'] as List).cast<String>().toSet();
    for (final name in (state['files'] as List).cast<String>()) {
      final destination = File(p.join(output.path, name));
      if (existing.contains(name)) {
        final backup = File(p.join(stage.path, 'backup', name));
        final restored = File(p.join(stage.path, 'restore-$name'));
        backup.copySync(restored.path);
        restored.renameSync(destination.path);
      } else if (destination.existsSync()) {
        destination.deleteSync();
      }
    }
    journal.deleteSync();
    if (stage.existsSync()) stage.deleteSync(recursive: true);
  }
  // Compilation can also be interrupted before a journal is prepared.
  for (final entry in output.listSync().whereType<Directory>()) {
    if (p.basename(entry.path).startsWith(materialStagingPrefix)) entry.deleteSync(recursive: true);
  }
}

/// All compiles must finish before calling this function. Publish flat outputs
/// with a recoverable journal and the manifest last; roll back on I/O failure.
void publishMaterialBatch({
  required Directory output,
  required Directory staging,
  required List<String> outputs,
  required List<String> staleOutputs,
  required String manifestName,
  required void Function(String) log,
}) {
  final files = {...outputs, ...staleOutputs, manifestName}.toList();
  final backup = Directory(p.join(staging.path, 'backup'))..createSync();
  final existing = <String>[];
  for (final name in files) {
    final source = File(p.join(output.path, name));
    if (source.existsSync()) {
      source.copySync(p.join(backup.path, name));
      existing.add(name);
    }
  }
  final journal = File(p.join(output.path, materialJournalName));
  final temporaryJournal = File(p.join(staging.path, 'journal.json'));
  temporaryJournal.writeAsStringSync(
    jsonEncode({'staging': p.basename(staging.path), 'files': files, 'existing': existing}),
    flush: true,
  );
  temporaryJournal.renameSync(journal.path);
  try {
    // An old manifest must not vouch for a partially promoted generation.
    final manifest = File(p.join(output.path, manifestName));
    if (manifest.existsSync()) manifest.deleteSync();
    for (final name in outputs) {
      File(p.join(staging.path, name)).renameSync(p.join(output.path, name));
      log('thermion materials: published $name');
    }
    for (final name in staleOutputs) {
      final file = File(p.join(output.path, name));
      if (file.existsSync()) file.deleteSync();
    }
    File(p.join(staging.path, manifestName)).renameSync(manifest.path);
    // Removing the journal commits the generation. Backups can now be discarded.
    journal.deleteSync();
  } catch (_) {
    recoverMaterialPublication(output);
    rethrow;
  }
}
