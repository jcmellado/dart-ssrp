### SQL Server Resolution Protocol ###

This Dart package implements a SSRP client that can be used to retrieve the list of SQL Server database instances on the network, or installed on a single machine, and their network protocol connection information.

It also can be used to retrieve the TCP port on which the SQL Server dedicated administrator connection (DAC) endpoint is listening.

### References ###

- [MC-SQLR](http://msdn.microsoft.com/en-us/library/cc219703.aspx): SQL Server Resolution Protocol

### Usage ###
Add the package to your `pubspec.yam` dependencies and create a new SSRP client:

```
import "package:ssrp/ssrp.dart" as ssrp;
```
```
var client = new ssrp.Client();
```

### List All Instances ###
The method `listAllInstances` returns the list of all SQL Server database instances on the network and their network protocol connection information:

```
var address = new InternetAddress("255.255.255.255");
client.listAllInstances(address).then((List<Instance> list) {
  ...
});
```

`address` must be an IPv4 broadcast or IPv6 multicast address.

### List Instance(s) ###
The method `listInstances` returns the list of SQL Server database instances and their network protocol connection information installed on a `server`:

```
var server = new InternetAddress("127.0.0.1");
client.listInstances(server).then((List<Instance> list) {
  ...
});
```

If the optional `instance` argument is not `null` then this method returns information related to the specific `instance` installed on the `server`:

```
var server = new InternetAddress("127.0.0.1");
var instance = "SQLEXPRESS";
client.listInstances(server, instance).then((List<Instance> list) {
  ...
});
```

### Intances ###
`Instance` objects have the following attributes:

* `server` : The name of the server.
* `name` : The name of the server instance.
* `isClustered` : Whether the server instance is clustered.
* `version` : The version of the server instance.
* `npPipeName` : The pipe name used to connect to the server instance.
* `tcpPort` : TCP port used to connect to the server instance.
* `viaNetBios` : NetBIOS name of the machine where the server resides.
* `viaListeners` : List of VIA listeners (see bellow).
* `rpcComputerName` : The name of the computer to connect to.
* `spxServiceName` : The SPX service name of the server.
* `adspObjectName` : The AppleTalk service object name.
* `bvItemName` : The Banyan VINES item name.
* `bvGroupName` : The Banyan VINES group name.
* `bvOrgName` : The Banyan VINES organization name.

`ViaListener` objects have the following attributes:

* `nic` : VIA network interface card (NIC) identifier.
* `port` : VIA NIC's port.

### DAC TCP Port ###
The method `getDatTcpPort` returns the TCP port on which the SQL Server dedicated administrator connection (DAC) endpoint is listening for a specific `instance` installed on a `server`:

```
var server = new InternetAddress("127.0.0.1");
var instance = "SQLEXPRESS";
client.getDacTcpPort(server, instance).then((int port) {
  ...
});
```

This method returns `null` if the port number could not be retrieved.

### Time-Out ###
The client has a `timeout` attribute with the amount of time expressed in seconds to wait for SSRP messages from the server(s). By default this value is `1`, but it can be modified as follow:

```
client.timeout = 5;
```

When listing all available instances, the client waits for responses up until the time-out expires.

When listing a specific instance, the client waits either for a time-out to occur or for the results of the request to return.

### Broadcast/Multicast ###
The client has a `multicastHops` attribute with the maximum network hops for multicast packages. By default this value is `1`, causing multicast traffic to stay on the local network, but it can be modified as follow:

```
client.multicastHops = 2;
```

### Logging ###
Invalid SSRP messages are automatically discarded and error messages are written to the log. Turn logging on using the following code:

```
import "package:logging/logging.dart";
```
```
Logger.root.level = Level.ALL;

Logger.root.onRecord.listen((rec) {
  print("${rec.time} ${rec.level.name} ${rec.loggerName} ${rec.message}");
});
```

### SQL Server Express ###
DAC is disabled by default. It can be activated adding the `-T7808` flag to the startup parameters of the server (SQL Server Configuration Manager >  SQL Server Services > SQL Server (SQLEXPRESS) > Startup Parameters).

The TCP port number retrieved with the `getDacTcpPort` method can be used for connecting a local server, or a remote server if the installation supports it,  with the `sqlcmd` command line tool:

```
sqlcmd -S [protocol:]server[\instance_name][,port]
```
Example:

```
sqlcmd -S tcp:127.0.0.1\SQLEXPRESS,51083
```
