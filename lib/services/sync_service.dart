import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:http/http.dart' as http;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SyncService {
  static HttpServer? _server;
  static final List<WebSocketChannel> _clients = [];

  // Broadcast to all connected clients
  static void broadcast(String type, Map<String, dynamic> data) {
    if (_clients.isEmpty) return;
    final message = jsonEncode({'type': type, 'data': data});
    final List<WebSocketChannel> toRemove = [];

    for (var client in List.from(_clients)) {
      try {
        client.sink.add(message);
      } catch (e) {
        print('Broadcast error for client: $e');
        toRemove.add(client);
      }
    }

    if (toRemove.isNotEmpty) {
      _clients.removeWhere((c) => toRemove.contains(c));
    }
  }

  // Start a local server on the "Master" register
  static Future<void> startServer({
    required Function(Map<String, dynamic>) onSaleReceived,
    required Function(String type, Map<String, dynamic> data) onUpdateReceived,
    required Future<void> Function(Map<String, dynamic> batch) onBatchUpdateReceived,
    required Future<Map<String, dynamic>> Function() onSyncRequested,
    required Future<Map<String, dynamic>> Function(
      String? registerId,
      String? deviceId,
      bool force,
    )
    onRegisterSelectionRequested,
  }) async {
    final router = Router();

    router.get('/ws', (Request request) {
      return webSocketHandler((WebSocketChannel socket, String? protocol) {
        _clients.add(socket);
        socket.stream.listen(
          (message) {
            try {
              final data = jsonDecode(message as String);
              if (data['type'] == 'ping') {
                socket.sink.add(jsonEncode({'type': 'pong'}));
              }
            } catch (e) {
              // Ignore invalid messages
            }
          },
          onDone: () {
            _clients.remove(socket);
          },
          onError: (err) {
            _clients.remove(socket);
          },
        );
      })(request);
    });

    // Endpoint for clients to push sales
    router.post('/sale', (Request request) async {
      try {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        print('Sale received from client...');
        await onSaleReceived(data);
        return Response.ok(jsonEncode({'status': 'success'}));
      } catch (e) {
        print('Error handling /sale: $e');
        return Response.internalServerError(body: e.toString());
      }
    });

    // Endpoint for clients to push any data update (Categories, Products, etc.)
    router.post('/update', (Request request) async {
      try {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        print('Update received from client: ${data['type']}');
        await onUpdateReceived(data['type'], data['data']);
        return Response.ok(jsonEncode({'status': 'success'}));
      } catch (e) {
        print('Error handling /update: $e');
        return Response.internalServerError(body: e.toString());
      }
    });

    router.post('/select-register', (Request request) async {
      try {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        final result = await onRegisterSelectionRequested(
          data['registerId'],
          data['deviceId'],
          data['force'] ?? false,
        );
        return Response.ok(jsonEncode(result));
      } catch (e) {
        return Response.internalServerError(body: e.toString());
      }
    });

    // Endpoint for batch incremental sync
    router.post('/sync-batch', (Request request) async {
      try {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        print('Batch update received from client...');
        await onBatchUpdateReceived(data);
        return Response.ok(jsonEncode({'status': 'success'}));
      } catch (e) {
        print('Error handling /sync-batch: $e');
        return Response.internalServerError(body: e.toString());
      }
    });

    // Endpoint for clients to pull full database state
    router.get('/sync', (Request request) async {
      try {
        final data = await onSyncRequested();
        return Response.ok(
          jsonEncode(data),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(body: e.toString());
      }
    });

    // Simple status check endpoint
    router.get('/status', (Request request) {
      return Response.ok(
        jsonEncode({
          'status': 'active',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    });

    // Endpoint to serve Logo file
    router.get('/logo', (Request request) async {
      final stateData = await onSyncRequested();
      final logoPath = stateData['logoPath'];
      if (logoPath != null && File(logoPath).existsSync()) {
        final file = File(logoPath);
        return Response.ok(
          file.openRead(),
          headers: {
            'Content-Type': 'image/png', // or appropriate type
            'Content-Length': file.lengthSync().toString(),
          },
        );
      }
      return Response.notFound('Logo topilmadi');
    });

    // Endpoint to serve Product Image
    router.get('/product-image/<id>', (Request request, String id) async {
      final stateData = await onSyncRequested();
      final products = stateData['products'] as List;
      final product = products.firstWhere(
        (p) => p['id'] == id,
        orElse: () => null,
      );

      if (product != null && product['imagePath'] != null) {
        final file = File(product['imagePath']);
        if (file.existsSync()) {
          return Response.ok(
            file.openRead(),
            headers: {
              'Content-Type': 'image/jpeg',
              'Content-Length': file.lengthSync().toString(),
            },
          );
        }
      }
      return Response.notFound('Rasm topilmadi');
    });

    _server = await io.serve(router.call, InternetAddress.anyIPv4, 8080, shared: true);
    print('Server ishga tushdi: ${_server!.address.address}:${_server!.port}');
  }

  // Client fetches status from Master
  static Future<Map<String, dynamic>?> fetchStatusFromMaster(
    String masterIp,
  ) async {
    try {
      final response = await http
          .get(Uri.parse('http://$masterIp:8080/status'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Client fetches full database state from Master
  static Future<Map<String, dynamic>?> fetchFullState(String masterIp) async {
    try {
      final response = await http.get(Uri.parse('http://$masterIp:8080/sync'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Fetch state error: $e');
      return null;
    }
  }

  // Client (Secondary Register) sends sale to Master
  static Future<bool> sendSaleToMaster(
    String masterIp,
    Map<String, dynamic> saleData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('http://$masterIp:8080/sale'),
        body: jsonEncode(saleData),
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Sinxronizatsiya xatosi: $e');
      return false;
    }
  }

  // Client sends generic update to Master
  static Future<bool> sendUpdateToMaster(
    String masterIp,
    String type,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('http://$masterIp:8080/update'),
        body: jsonEncode({'type': type, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Update send error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> selectRegisterOnMaster(
    String masterIp,
    String? registerId,
    String? deviceId,
    bool force,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('http://$masterIp:8080/select-register'),
        body: jsonEncode({
          'registerId': registerId,
          'deviceId': deviceId,
          'force': force,
        }),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Select register error: $e');
      return null;
    }
  }

  static Future<String?> autoDiscoverMaster() async {
    try {
      final interfaces = await NetworkInterface.list();
      Set<String> subnets = {};

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              subnets.add("${parts[0]}.${parts[1]}.${parts[2]}");
            }
          }
        }
      }

      // Professional: Add common subnets as fallback for MikroTik/VLAN setups
      final commonSubnets = ['192.168.1', '192.168.0', '192.168.3', '192.168.8', '192.168.100', '10.0.0'];
      for (var s in commonSubnets) {
        subnets.add(s);
      }

      print('Skanerlanayotgan subnetlar: $subnets');

      for (var subnet in subnets) {
        final found = await _scanSubnet(subnet);
        if (found != null) return found;
      }
    } catch (e) {
      print('Discovery error: $e');
    }
    return null;
  }

  static Future<String?> _scanSubnet(String subnet) async {
    // Parallel scanning of 254 IPs
    final List<Future<String?>> tasks = [];
    for (int i = 1; i < 255; i++) {
      tasks.add(_checkIp("$subnet.$i"));
    }

    final results = await Future.wait(tasks);
    for (var res in results) {
      if (res != null) return res;
    }
    return null;
  }

  static Future<String?> _checkIp(String ip) async {
    try {
      final response = await http
          .get(Uri.parse('http://$ip:8080/status'))
          .timeout(const Duration(milliseconds: 800)); // Optimal timeout for local network
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'active') {
          print('Master topildi: $ip');
          return ip;
        }
      }
    } catch (_) {
      // Ignore errors for non-existent IPs or closed ports
    }
    return null;
  }

  static void stopServer() {
    _server?.close();
  }
}
