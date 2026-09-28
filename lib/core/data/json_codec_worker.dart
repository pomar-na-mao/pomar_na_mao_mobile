import 'dart:convert';
import 'dart:isolate';

const jsonCodecWorkerBatchSize = 500;

Future<List<Map<String, dynamic>>> decodeJsonMapsInWorker(
  Iterable<Object?> values, {
  int batchSize = jsonCodecWorkerBatchSize,
}) async {
  final decoded = <Map<String, dynamic>>[];
  var batch = <Object?>[];
  for (final value in values) {
    batch.add(value);
    if (batch.length >= batchSize) {
      decoded.addAll(await Isolate.run(() => _decodeJsonMaps(batch)));
      batch = <Object?>[];
    }
  }
  if (batch.isNotEmpty) {
    decoded.addAll(await Isolate.run(() => _decodeJsonMaps(batch)));
  }
  return decoded;
}

Future<List<String>> encodeJsonMapsInWorker(
  Iterable<Map<String, dynamic>> values, {
  int batchSize = jsonCodecWorkerBatchSize,
}) async {
  final encoded = <String>[];
  var batch = <Map<String, dynamic>>[];
  for (final value in values) {
    batch.add(value);
    if (batch.length >= batchSize) {
      encoded.addAll(await Isolate.run(() => _encodeJsonMaps(batch)));
      batch = <Map<String, dynamic>>[];
    }
  }
  if (batch.isNotEmpty) {
    encoded.addAll(await Isolate.run(() => _encodeJsonMaps(batch)));
  }
  return encoded;
}

List<Map<String, dynamic>> _decodeJsonMaps(List<Object?> values) => values
    .map((value) => jsonDecode(value as String) as Map<String, dynamic>)
    .toList(growable: false);

List<String> _encodeJsonMaps(List<Map<String, dynamic>> values) =>
    values.map(jsonEncode).toList(growable: false);
