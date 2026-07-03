import 'dart:async';

import 'package:multicast_dns/multicast_dns.dart';

/// A mesh node discovered on the local network.
class DiscoveredNode {
  final String host;
  final int port;

  const DiscoveredNode(this.host, this.port);

  /// Base URL of the node's sync REST API.
  String get baseUrl => 'http://$host:$port';

  @override
  bool operator ==(Object other) =>
      other is DiscoveredNode && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => 'DiscoveredNode($baseUrl)';
}

/// Discovers autonomous mesh sync nodes (e.g. solar-powered Raspberry Pi relay
/// stations) on the local network via mDNS / DNS-SD.
///
/// Nodes advertise the service type [serviceType]. Discovery is only run on
/// demand — typically when the tracking engine reports arrival at a place — to
/// conserve resources rather than scanning continuously.
class NodeDiscoveryService {
  NodeDiscoveryService._();
  static final NodeDiscoveryService instance = NodeDiscoveryService._();

  /// DNS-SD service type advertised by chaos-tours sync nodes.
  static const String serviceType = '_chaossync._tcp.local';

  /// Performs a single discovery sweep and returns the reachable nodes.
  Future<List<DiscoveredNode>> discover({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final client = MDnsClient();
    final found = <DiscoveredNode>{};
    try {
      await client.start();
      await _sweep(client, found).timeout(timeout, onTimeout: () {});
    } catch (_) {
      // mDNS may be unavailable (no network / permissions) — treat as no nodes.
    } finally {
      client.stop();
    }
    return found.toList();
  }

  Future<void> _sweep(MDnsClient client, Set<DiscoveredNode> found) async {
    await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer(serviceType),
    )) {
      await for (final SrvResourceRecord srv
          in client.lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName),
          )) {
        // Prefer resolving to a concrete IPv4 address; fall back to the target
        // hostname if address resolution yields nothing.
        var resolved = false;
        await for (final IPAddressResourceRecord ip
            in client.lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target),
            )) {
          found.add(DiscoveredNode(ip.address.address, srv.port));
          resolved = true;
        }
        if (!resolved) {
          found.add(DiscoveredNode(srv.target, srv.port));
        }
      }
    }
  }
}
