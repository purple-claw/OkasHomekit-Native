// lib/services/mdns_resolver.dart
import 'package:multicast_dns/multicast_dns.dart';

class MDNSResolver {
  static Future<String?> resolveHost(String hostname) async {
    try {
      final client = MDnsClient();
      await client.start();

      final queryHost = hostname.endsWith('.') ? hostname : '$hostname.';
      await for (final IPAddressResourceRecord record
          in client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(queryHost),
          )) {
        client.stop();
        return record.address.address;
      }

      for (final serviceType in ['_okas._tcp.local.', '_hap._tcp.local.']) {
        await for (final PtrResourceRecord ptr
            in client.lookup<PtrResourceRecord>(
              ResourceRecordQuery.serverPointer(serviceType),
            )) {
          await for (final SrvResourceRecord srv
              in client.lookup<SrvResourceRecord>(
                ResourceRecordQuery.service(ptr.domainName),
              )) {
            if (srv.target.contains(hostname)) {
              client.stop();
              return srv.target.endsWith('.')
                  ? srv.target.substring(0, srv.target.length - 1)
                  : srv.target;
            }
          }
        }
      }

      client.stop();
      return null;
    } catch (e) {
      print('mDNS resolution error: $e');
      return null;
    }
  }
}
