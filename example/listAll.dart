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

import "dart:io" as io show InternetAddress;
import "package:logging/logging.dart" as log show Level, Logger;
import "package:ssrp/ssrp.dart" as ssrp show Client;

void main(List<String> args) {
  if (args.length != 1) {
    print("Usage: listAll <address>");
    print(" address = Broadcast/Multicast IP address (e.g. '255.255.255.255')");
    return;
  }

  log.Logger.root.level = log.Level.ALL;
  log.Logger.root.onRecord.listen((rec) {
    print("${rec.time} ${rec.level.name} ${rec.loggerName} ${rec.message}");
  });

  var client = new ssrp.Client();
  var address = new io.InternetAddress(args[0]);

  client.timeout = 5;

  client.listAllInstances(address).then(print);
}
