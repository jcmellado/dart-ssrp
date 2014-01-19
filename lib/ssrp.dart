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

/*
 * References:
 * - [MC-SQLR]: SQL Server Resolution Protocol
 *   http://msdn.microsoft.com/en-us/library/cc219703.aspx
 */

library ssrp;

import "dart:async" show Completer, Future, Timer;
import "dart:io" show InternetAddress, InternetAddressType, RawDatagramSocket,
    RawSocketEvent, SYSTEM_ENCODING;
import "package:logging/logging.dart" show Logger;

part "src/client.dart";
part "src/encoding.dart";
part "src/parser.dart";

/// SSRP protocol version.
const int SSRP_PROTOCOL_VERSION = 0x01;

/// SSRP UDP port number.
const int SSRP_UDP_PORT = 1434;

/**
 * SSRP client that can be used to retrieve the list of SQL Server database
 * instances on the network, or installed on a single machine, and their
 * network protocol connection information.
 *
 * It also can be used to retrieve the TCP port on which the SQL Server
 * dedicated administrator connection (DAC) endpoint is listening.
 */
abstract class Client {

  factory Client() = _ClientImpl;

  /**
   * Returns the list of all SQL Server database instances on the network and
   * their network protocol connection information.
   *
   * [address] must be an IPv4 broadcast or IPv6 multicast address.
   *
   *   var address = new InternetAddress("255.255.255.255");
   *   client.listAllInstances(address).then((list) {
   *     ...
   *   });
   */
  Future<List<Instance>> listAllInstances(InternetAddress address);

  /**
   * Returns the list of SQL Server database instances and their network
   * protocol connection information installed on the [server].
   *
   *   var server = new InternetAddress("127.0.0.1");
   *   client.listInstances(server).then((list) {
   *     ...
   *   });
   *
   * If [instance] is not [null] then this method returns information
   * related to the specific [instance] installed on the [server].
   *
   *   var server = new InternetAddress("127.0.0.1");
   *   var instance = "SQLEXPRESS";
   *   client.listInstances(server, instance).then((list) {
   *     ...
   *   });
   *
   */
  Future<List<Instance>> listInstances(InternetAddress server, [String instance]);

  /**
   * Returns the TCP port on which the SQL Server dedicated administrator
   * connection (DAC) endpoint is listening for a specific [instance]
   * installed on a [server].
   *
   *   var server = new InternetAddress("127.0.0.1");
   *   var instance = "SQLEXPRESS";
   *   client.getDacTcpPort(server, instance).then((port) {
   *     ...
   *   });
   *
   * Returns [null] if the port number could not be retrieved.
   */
  Future<int> getDacTcpPort(InternetAddress server, String instance);

  /**
   * The amount of time expressed in seconds to wait for SSRP messages
   * from the server(s). By default this value is 1.
   *
   *   client.timeout = 5;
   */
  int timeout;

  /**
   * The maximum network hops for multicast packages. By default this value
   * is 1, causing multicast traffic to stay on the local network.
   */
  int multicastHops;
}

/**
 * Information about a SQL Server instance.
 */
class Instance {

  /**
   * The name of the server.
   */
  String server;

  /**
   * The name of the server instance.
   */
  String name;

  /**
   * Whether the server instance is clustered.
   */
  bool isClustered;

  /**
   * The version of the server instance.
   */
  String version;

  /**
   * The pipe name used to connect to the server instance.
   */
  String npPipeName;

  /**
   * TCP port used to connect to the server instance.
   */
  int tcpPort;

  /**
   * NetBIOS name of the machine where the server resides.
   */
  String viaNetBios;

  /**
   * List of VIA listeners. See [ViaListener] for more info.
   */
  List<ViaListener> viaListeners;

  /**
   * The name of the computer to connect to.
   */
  String rpcComputerName;

  /**
   * The SPX service name of the server.
   */
  String spxServiceName;

  /**
   * The AppleTalk service object name.
   */
  String adspObjectName;

  /**
   * The Banyan VINES item name.
   */
  String bvItemName;

  /**
   * The Banyan VINES group name.
   */
  String bvGroupName;

  /**
   * The Banyan VINES organization name.
   */
  String bvOrgName;

  @override
  String toString() {
    var str = new StringBuffer("""Instance: server=$server, name=$name"""
        """, isClustered=$isClustered, version=$version""");
    if (npPipeName != null) {
      str.write(", np.pipeName=$npPipeName");
    }
    if (tcpPort != null) {
      str.write(", tcp.port=$tcpPort");
    }
    if (viaNetBios != null) {
      str.write(", via.netbios=$viaNetBios, via.listeners=$viaListeners");
    }
    if (rpcComputerName != null) {
      str.write(", rpc.computerName=$rpcComputerName");
    }
    if (spxServiceName != null) {
      str.write(", spx.serviceName=$spxServiceName");
    }
    if (adspObjectName != null) {
      str.write(", adsp.objectName=$adspObjectName");
    }
    if (bvItemName != null) {
      str.write(", bv.itemName=$bvItemName, bv.groupName=$bvGroupName, bv.orgName=$bvOrgName");
    }
    return str.toString();
  }
}

/**
 * Virtual Interface Architecture (VIA) listener identifier.
 */
class ViaListener {

  /**
   * VIA network interface card (NIC) identifier.
   */
  String nic;

  /**
   * VIA NIC's port.
   */
  int port;

  @override
  String toString() => "ViaListener: nic=$nic, port=$port";
}
