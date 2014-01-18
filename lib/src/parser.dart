/*
  Copyright (c) 2014 Juan Mellado

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
*/

part of ssrp;

// Server messages.
const int _SRV_RESP = 0x05;

// Tokens.
const String _SEMICOLON     = ";";
const String _SERVER_NAME   = "ServerName";
const String _INSTANCE_NAME = "InstanceName";
const String _IS_CLUSTERED  = "IsClustered";
const String _VERSION       = "Version";
const String _NP_INFO       = "np";
const String _TCP_INFO      = "tcp";
const String _VIA_INFO      = "via";
const String _RPC_INFO      = "rpc";
const String _SPX_INFO      = "spx";
const String _ADSP_INFO     = "adsp";
const String _BV_INFO       = "bv";
const String _SEMICOLONS    = ";;";

/**
 * Parses SSRP server messages.
 *
 * Invalid messages are automatically discarded.
 *
 * Turn logging on using the following code:
 *
 *   Logger.root.level = Level.ALL;
 *
 *   Logger.root.onRecord.listen((rec) {
 *     print("${rec.time} ${rec.level.name} ${rec.loggerName} ${rec.message}");
 *   });
 */
abstract class _Parser {
  static final Logger _log = new Logger("ssrp.Parser");

  static List<Instance> parseList(List<int> bytes) => _parse(bytes, _parseList);

  static int parsePort(List<int> bytes) => _parse(bytes, _parsePort);

  static _parse(List<int> bytes, parse(List<int> bytes)) {
    try {
      return parse(bytes);
    } on FormatException catch(e) {
      return null;
    }
  }

  static List<Instance> _parseList(List<int> bytes) {
    if (bytes == null) _error("Invalid null response");
    if (bytes.length < 3) _error("Invalid response length: ${bytes.length}");
    if (bytes[0] != _SRV_RESP) _error("Invalid response type: ${bytes[0]}");

    var size = bytes[1] | (bytes[2] << 8);
    if ((size == 0) || (size + 3 > bytes.length)) _error("Invalid data size: ${size}");

    // Poor Man's CharsetDecoder.
    var data = new String.fromCharCodes(bytes.sublist(3, 3 + size));

    return _parseInstances(data);
  }

  static int _parsePort(List<int> bytes) {
    if (bytes == null) _error("Invalid null response");
    if (bytes.length != 6) _error("Invalid response length: ${bytes.length}");
    if (bytes[0] != _SRV_RESP) _error("Invalid response type: ${bytes[0]}");

    var size = bytes[1] | (bytes[2] << 8);
    if (size != 6) _error("Invalid data size: ${size}");

    if (bytes[3] != SSRP_PROTOCOL_VERSION) _error("Invalid protocol version: ${bytes[3]}");

    return bytes[4] | (bytes[5] << 8);
  }

  static List<Instance> _parseInstances(String data) {
    var instances = new List<Instance>();

    var start = 0;
    do {
      var end = data.indexOf(_SEMICOLONS, start);
      if (end == -1) _error("Missing token: '$_SEMICOLONS'");

      var part = data.substring(start, end);
      if (_byteLength(part) + 2 > 1024) _error("Instance greater than 1024 bytes");

      var instance = _parseInstance(part);
      instances.add(instance);

      start = end + 2;
    } while(start != data.length);

    return instances;
  }

  static Instance _parseInstance(String data) {
    var instance = new Instance();

    var parts = data.split(_SEMICOLON);
    if (parts.length < 8) _error("Unexpected end of message");

    if (parts[0] != _SERVER_NAME) _error("Mising token: '$_SERVER_NAME'");
    if (_byteLength(parts[1]) > 255) _error("SERVERNAME greater than 255 bytes");
    instance.server = parts[1];

    if (parts[2] != _INSTANCE_NAME) _error("Missing token: '$_INSTANCE_NAME'");
    if (_byteLength(parts[3]) > 255) _error("INSTANCENAME greater than 255 bytes");
    if (parts[3].length > 16) _warning("INSTANCENAME greater than 16 characters");
    instance.name = parts[3];

    if (parts[4] != _IS_CLUSTERED) _error("Missing token: '$_IS_CLUSTERED'");
    if ((parts[5] != "Yes") && (parts[5] != "No")) _error("Invalid YES_OR_NO value");
    instance.isClustered = parts[5] == "Yes";

    if (parts[6] != _VERSION) _error("Missing token: '$_VERSION'");
    if (parts[7].isEmpty) _error("VERSION_STRING is empty");
    if (_byteLength(parts[7]) > 16) _error("VERSION_STRING greater than 16 bytes");
    if (!new RegExp(r"^[0-9\.]+$").hasMatch(parts[7])) _error("VERSION_STRING doesn't match [0-9\\.]+");
    instance.version = parts[7];

    return _parseInfo(instance, parts);
  }

  static Instance _parseInfo(Instance instance, List<String> parts) {
    for (var i = 8; i < parts.length; ++ i) {
      switch(parts[i]) {
        case _NP_INFO:
          if (instance.npPipeName != null) _error("'$_NP_INFO' listed more than once");
          if (++ i == parts.length) _error("Unexpected end of message");
          instance.npPipeName = parts[i];
          break;
        case _TCP_INFO:
          if (instance.tcpPort != null) _error("'$_TCP_INFO' listed more than once");
          if (++ i == parts.length) _error("Unexpected end of message");
          var port = int.parse(parts[i], onError: (_) => null);
          if (port == null) _error("Invalid TCP_PORT value");
          if ((port < 0) || (port > 65535)) _error("Invalid TCP_PORT value");
          instance.tcpPort = port;
          break;
        case _VIA_INFO:
          if (instance.viaNetBios != null) _error("'$_VIA_INFO' listed more than once");
          if (++ i == parts.length) _error("Unexpected end of message");
          if (_byteLength(parts[i]) > 128) _warning("VIA_INFO greater than 128 bytes");
          var via = parts[i].split(",");
          if (via.length < 2) _error("Invalid VIA_PARAMETERS value");
          if (_byteLength(via[0]) > 15) _error("NETBIOS greater than 15 bytes");
          instance.viaNetBios = via[0];
          instance.viaListeners = new List<ViaListener>();
          for (var i = 1; i < via.length; ++ i) {
            var listener = via[i].split(":");
            if (listener.length != 2) _error("Invalid VIALISTENINFO value");
            var port = int.parse(listener[1], onError: (_) => null);
            if (port == null) _error("Invalid VIAPORT value");
            instance.viaListeners.add(new ViaListener()..nic = listener[0]..port = port);
          }
          break;
        case _RPC_INFO:
          if (instance.rpcComputerName != null) _error("'$_RPC_INFO' listed more than once");
          if (++ i == parts.length) _error("Unexpected end of message");
          if (parts[i].length > 127) _warning("COMPUTERNAME greater than 127 characters");
          instance.rpcComputerName = parts[i];
          break;
        case _SPX_INFO:
          if (instance.spxServiceName != null) _error("'$_SPX_INFO' listed more than once");
          if (++ i == parts.length) _error("Unexpected end of message");
          if (_byteLength(parts[i]) > 1024) _error("SERVICENAME greater than 1024 bytes");
          if (parts[i].length > 127) _warning("SERVICENAME greater than 127 characters");
          instance.spxServiceName = parts[i];
          break;
        case _ADSP_INFO:
          if (instance.adspObjectName != null) _error("'$_ADSP_INFO' listed more than once");
          if (++ i == parts.length) _error("Unexpected end of message");
          if (parts[i].length > 127) _warning("ADSPOBJECTNAME greater than 127 characters");
          instance.adspObjectName = parts[i];
          break;
        case _BV_INFO:
          if (instance.bvItemName != null) _error("'$_BV_INFO' listed more than once");
          if (++ i == parts.length) _error("Unexpected end of message");
          if (parts[i].length > 127) _warning("ITEMNAME greater than 127 characters");
          instance.bvItemName = parts[i];
          if (++ i == parts.length) _error("Unexpected end of message");
          if (parts[i].length > 127) _warning("GROUPNAME greater than 127 characters");
          instance.bvGroupName = parts[i];
          if (++ i == parts.length) _error("Unexpected end of message");
          if (parts[i].length > 127) _warning("ORGNAME greater than 127 characters");
          instance.bvOrgName = parts[i];
          break;
        default:
          _error("Unknow protocol identifier");
      }
    }
    return instance;
  }

  static void _warning(String message) {
    _log.warning(message);
  }

  static void _error(String message) {
    _log.finest(message);

    throw new FormatException(message);
  }
}
