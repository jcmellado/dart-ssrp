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

// Client messages.
const int _CLNT_BCAST_EX   = 0x02;
const int _CLNT_UCAST_EX   = 0x03;
const int _CLNT_UCAST_INST = 0x04;
const int _CLNT_UCAST_DAC  = 0x0F;

/**
 * SSRP client implementation.
 */
class _ClientImpl implements Client {
  int timeout = 1;
  int multicastHops = 1;

  Future<List<Instance>> listAllInstances(InternetAddress address) {
    if (address == null) throw new ArgumentError("address must be not null");
    return _broadcast(address);
  }

  Future<List<Instance>> listInstances(InternetAddress server, [String instance]) {
    if (server == null) throw new ArgumentError("server must be not null");
    if (instance != null) _checkInstanceLength(instance);
    return instance == null ? _unicast(server) : _unicastInstance(server, instance);
  }

  Future<int> getDacTcpPort(InternetAddress server, String instance) {
    if (server == null) throw new ArgumentError("server must be not null");
    if (instance == null) throw new ArgumentError("instance must be not null");
    _checkInstanceLength(instance);
    return _unicastDac(server, instance);
  }

  Future<List<Instance>> _broadcast(InternetAddress address)
    => new _ListCommand(_CLNT_BCAST_EX, address).execute(this);

  Future<List<Instance>> _unicast(InternetAddress server)
    => new _ListCommand(_CLNT_UCAST_EX, server).execute(this);

  Future<List<Instance>> _unicastInstance(InternetAddress server, String instance)
    => new _ListCommand(_CLNT_UCAST_INST, server, instance).execute(this);

  Future<int> _unicastDac(InternetAddress server, String instance)
    => new _PortCommand(_CLNT_UCAST_DAC, server, instance).execute(this);

  void _checkInstanceLength(String instance) {
    if (_byteLength(instance) > 32) {
      throw new ArgumentError("instance must not be greater than 32 bytes in length");
    }
  }
}

/**
 * Concrete command used to list SQL Server instances.
 */
class _ListCommand extends _Command<List<Instance>> {

  _ListCommand(int type, InternetAddress address, [String instance])
      : super(type, address, instance) {
    _result = new List<Instance>();
  }

  bool _onData(List<int> data) {
    var list = _Parser.parseList(data);
    if (list != null) {
      _result.addAll(list);
    }
    return _type == _CLNT_UCAST_INST; // false = wait for more results.
  }
}

/**
 * Concrete command used to get DAC TCP port number.
 */
class _PortCommand extends _Command<int> {

  _PortCommand(int type, InternetAddress address, [String instance])
      : super(type, address, instance);

  bool _onData(List<int> data) {
    _result = _Parser.parsePort(data);

    return true; // true = done.
  }
}

/**
 * Abstract SSRP command.
 */
abstract class _Command<T> {
  final int _type;
  final InternetAddress _address;
  final String _instance;

  T _result;

  _Command(this._type, this._address, [this._instance]);

  Future<T> execute(Client client) => _execute(client.timeout, client.multicastHops);

  Future<T> _execute(int timeout, int multicastHops) {
    var completer = new Completer<T>();

    RawDatagramSocket.bind(_host(), 0).then((socket) {
      _enableBroadcast(socket, multicastHops);

      socket.send(_request(), _address, SSRP_UDP_PORT);

      var timer = new Timer(new Duration(seconds: timeout), () {
        socket.close();
        completer.complete(_result);
      });

      socket.where((event) => event == RawSocketEvent.READ).listen((_) {
        if (_onData(socket.receive().data)) {
          timer.cancel();
          socket.close();
          completer.complete(_result);
        }
      });

    });

    return completer.future;
  }

  bool _onData(List<int> data);

  InternetAddress _host()
    => _address.type == InternetAddressType.IP_V4 ? InternetAddress.ANY_IP_V4
                                                  : InternetAddress.ANY_IP_V6;

  void _enableBroadcast(RawDatagramSocket socket, int multicastHops) {
    if (_type == _CLNT_BCAST_EX) {
      if (_address.type == InternetAddressType.IP_V4) {
        socket.broadcastEnabled = true;
      }
      if (_address.type == InternetAddressType.IP_V6) {
        socket.multicastHops = multicastHops;
        socket.joinMulticast(_address);
      }
    }
  }

  List<int> _request() {
    var request = new List<int>()..add(_type);

    if (_type == _CLNT_UCAST_INST) {
      request..addAll(_mbcs(_instance))..add(0);
    }
    if (_type == _CLNT_UCAST_DAC) {
      request..add(SSRP_PROTOCOL_VERSION)..addAll(_mbcs(_instance))..add(0);
    }

    return request;
  }
}
