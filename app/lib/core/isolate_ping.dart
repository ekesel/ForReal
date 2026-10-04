import 'dart:isolate';
import 'dart:ui';

/// Background isolates (capture, notification buttons) write to the same database
/// as the UI. This tells the UI isolate to re-read, since database change streams
/// do not cross isolates.
const _portName = 'forreal_ui_refresh';

/// Called in the UI isolate. [onChanged] runs whenever a background isolate wrote.
ReceivePort listenForBackgroundChanges(void Function() onChanged) {
  final port = ReceivePort();
  IsolateNameServer.removePortNameMapping(_portName);
  IsolateNameServer.registerPortWithName(port.sendPort, _portName);
  port.listen((_) => onChanged());
  return port;
}

void stopListeningForBackgroundChanges(ReceivePort port) {
  IsolateNameServer.removePortNameMapping(_portName);
  port.close();
}

/// Called in a background isolate after it changed local data.
void notifyUiOfChanges() {
  IsolateNameServer.lookupPortByName(_portName)?.send('changed');
}
