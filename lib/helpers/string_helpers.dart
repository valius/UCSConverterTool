import 'package:flutter/material.dart';

extension StringHelpers on String {
  String trimUsingCharacterSet(Set<String> charSet) {
    String result = "";

    //Start with left
    Characters chars = Characters(this);

    int leftMostIndex = 0;
    int rightMostIndex = chars.length - 1;

    for (int i = 0; i < chars.length; i++) {
      if (charSet.contains(chars.elementAt(i))) {
        leftMostIndex++;
      } else {
        //Found a character that is not set to be trimmed, end
        break;
      }
    }

    for (int i = chars.length - 1; i > leftMostIndex; i--) {
      if (charSet.contains(chars.elementAt(i))) {
        rightMostIndex--;
      } else {
        //Found a character that is not set to be trimmed, end
        break;
      }
    }

    //Build out result string using indices from above
    for (int i = leftMostIndex; i <= rightMostIndex; i++) {
      result += chars.elementAt(i);
    }

    return result;
  }
}
