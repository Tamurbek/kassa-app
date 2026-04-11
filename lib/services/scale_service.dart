import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// A service to handle communication with professional USB/Serial scales.
/// Supports common protocols like NCI, CAS, and POS.
class ScaleService {
  static final ScaleService _instance = ScaleService._internal();
  factory ScaleService() => _instance;
  ScaleService._internal();

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  /// Mock state for demonstration if no real scale is connected.
  /// In a real implementation, this would use flutter_libserialport.
  Future<double> readWeight({
    String? port,
    int baudRate = 9600,
    String protocol = 'NCI',
  }) async {
    // Simulate connection delay
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      if (kDebugMode) {
        print('Connecting to scale on $port at $baudRate baud using $protocol protocol...');
      }

      // TODO: Real implementation would look like this:
      /*
      final serialPort = SerialPort(port);
      if (!serialPort.openReadWrite()) {
        throw Exception('Portni ochib bo\'lmadi');
      }
      
      // Send request command based on protocol
      if (protocol == 'NCI') {
        serialPort.write(Uint8List.fromList('W\r'.codeUnits));
      } else if (protocol == 'CAS') {
        serialPort.write(Uint8List.fromList([0x05])); // ENQ
      }

      // Read response
      final reader = SerialPortReader(serialPort);
      final response = await reader.stream.first.timeout(Duration(seconds: 2));
      return _parseWeight(response, protocol);
      */

      // Simulation: Return a random weight between 0.1 and 5.0 kg
      final random = Random();
      return (random.nextDouble() * 4.9 + 0.1);
    } catch (e) {
      debugPrint('Scale Error: $e');
      rethrow;
    }
  }

  double _parseWeight(List<int> data, String protocol) {
    final raw = String.fromCharCodes(data);
    // Parse logic for NCI: usually looks like "  1.234 kg "
    final match = RegExp(r'(\d+\.\d+)').firstMatch(raw);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }
}
