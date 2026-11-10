import 'dart:convert';
import 'dart:io';

const String subDomainHost = "redloop.safolota.com";
const String fallbackIp = "144.79.219.130";
const String apiKey = "redloop2026secure";

Future<String> resolveIp() async {
  try {
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse("https://dns.google/resolve?name=" + subDomainHost + "&type=A"));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    client.close();
    final data = jsonDecode(body);
    final ans = data['Answer'] as List;
    for (var a in ans) {
      if (a['type'] == 1) return a['data'].toString();
    }
  } catch (_) {}
  return fallbackIp;
}

String decodeChunked(String s) {
  String out = "";
  int i = 0;
  while (i < s.length) {
    int end = s.indexOf("\r\n", i);
    if (end == -1) break;
    int len = int.tryParse(s.substring(i, end).trim(), radix: 16) ?? 0;
    if (len == 0) break;
    int start = end + 2;
    if (start + len > s.length) break;
    out += s.substring(start, start + len);
    i = start + len + 2;
  }
  return out;
}

Future<String> httpsRequest(String method, String action, Map<String, String> body) async {
  final ip = await resolveIp();
  String encoded = body.entries.map((e) => Uri.encodeComponent(e.key) + "=" + Uri.encodeComponent(e.value)).join("&");
  final sock = await Socket.connect(ip, 443, timeout: const Duration(seconds: 10));
  final sec = await SecureSocket.secure(sock, host: subDomainHost, onBadCertificate: (c) => true);
  String req;
  if (method == "POST") {
    req = "POST /api.php?action=" + action + " HTTP/1.1\r\nHost: " + subDomainHost + "\r\nX-API-KEY: " + apiKey + "\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: " + encoded.length.toString() + "\r\nConnection: close\r\n\r\n" + encoded;
  } else {
    req = "GET /api.php?action=" + action + " HTTP/1.1\r\nHost: " + subDomainHost + "\r\nX-API-KEY: " + apiKey + "\r\nConnection: close\r\n\r\n";
  }
  sec.write(req);
  await sec.flush();
  List<int> bytes = [];
  await for (var chunk in sec) {
    bytes.addAll(chunk);
  }
  try { await sec.close(); } catch (_) {}
  String resp = utf8.decode(bytes, allowMalformed: true);
  int idx = resp.indexOf("\r\n\r\n");
  String b = idx >= 0 ? resp.substring(idx + 4) : resp;
  if (resp.toLowerCase().contains("transfer-encoding: chunked")) b = decodeChunked(b);
  return b;
}
