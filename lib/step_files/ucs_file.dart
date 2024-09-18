import 'dart:developer';
import 'dart:io';

import 'andamiro_common.dart';

enum UCSChartType {
  single,
  double,
  singlePerformance,
  doublePerformance,
  invalid
}

class UCSBlockLine {
  List<AMNoteType> notes = [];
}

class UCSBlock {
  double bpm = 0;
  double startTime = 0;
  int beatPerMeasure = 4; //Default
  int beatSplit = 0;
  List<UCSBlockLine> lines = [];
}

class UCSFile {
  final String _filename;
  final List<UCSBlock> _blocks = [];

  List<UCSBlock> get getBlocks {
    return _blocks;
  }

  //Default to invalid
  UCSChartType chartType = UCSChartType.invalid;

  UCSFile(this._filename);

  void outputToFile() async {
    var file = File(_filename);
    var sink = file.openWrite();
    try {
      //Write chart tags
      sink.writeln(':Format=1');
      String mode;
      switch (chartType) {
        case UCSChartType.doublePerformance:
          mode = ':Mode=D-Performance';
          break;
        case UCSChartType.singlePerformance:
          mode = ':Mode=S-Performance';
          break;
        case UCSChartType.double:
          mode = ':Mode=Double';
          break;
        default:
          mode = ':Mode=Single';
          break;
      }

      sink.writeln(mode);

      for (UCSBlock block in _blocks) {
        //Block tags
        //Remove .0 from bpm and start time if they are actually integers
        String bpmString = block.bpm.toString();
        if (block.bpm.truncateToDouble() == block.bpm) {
          bpmString = block.bpm.toStringAsFixed(0);
        }
        sink.writeln(':BPM=$bpmString');
        String startTimeString = block.startTime.toString();
        if (block.startTime.truncateToDouble() == block.startTime) {
          startTimeString = block.startTime.toStringAsFixed(0);
        }
        sink.writeln(':Delay=$startTimeString');
        sink.writeln(':Beat=${block.beatPerMeasure}');
        sink.writeln(':Split=${block.beatSplit}');

        //notes
        for (UCSBlockLine line in block.lines) {
          for (AMNoteType note in line.notes) {
            String charToWrite;
            switch (note) {
              case AMNoteType.regular:
                charToWrite = 'X';
                break;
              case AMNoteType.holdBegin:
                charToWrite = 'M';
                break;
              case AMNoteType.hold:
                charToWrite = 'H';
                break;
              case AMNoteType.holdEnd:
                charToWrite = 'W';
                break;
              default:
                charToWrite = '.';
                break;
            }
            sink.write(charToWrite);
          }
          sink.writeln("");
        }
      }
    } catch (e) {
      String message = 'Error $e when trying to write $_filename!';
      log(message);
    }

    await sink.flush();
    await sink.close();
  }
}
