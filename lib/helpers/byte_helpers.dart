import 'dart:typed_data';

(int, int) readUint32BytesFromByteList(int index, List<int> byteList) {
  List<int> subList = byteList.sublist(index, index + 4);

  return (index + 4, readUint32Bytes(subList));
}

int readUint32Bytes(List<int> bytes) {
  if (bytes.length != 4) {
    //This input is not the expected list of 4 bytes
    return 0;
  }

  //STX uses little endian
  return ((bytes[3] << 24) + (bytes[2] << 16) + (bytes[1] << 8) + (bytes[0]));
}

(int, double) readFloat32BytesFromByteList(int index, List<int> byteList) {
  List<int> subList = byteList.sublist(index, index + 4);

  return (index + 4, readFloat32Bytes(subList));
}

double readFloat32Bytes(List<int> bytes) {
  if (bytes.length != 4) {
    //This input is not the expected list of 4 bytes
    return 0;
  }

  //Do double conversion, and since we only have 4 bytes, we only have 1 double
  //Reverse byte order to convert from little to big endian
  final byteData =
      ByteData.sublistView(Uint8List.fromList(bytes.reversed.toList()));
  return byteData.getFloat32(0);
}
