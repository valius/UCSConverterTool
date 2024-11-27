import "package:path/path.dart" as p;

import 'package:ucsconvertertool/step_files/andamiro_common.dart';
import 'package:ucsconvertertool/step_files/stx_file.dart';

import '../step_files/ucs_file.dart';
import 'i_converter.dart';

class STXConverter implements IConverter {
  late final String _filename;

  STXConverter(this._filename);

  UCSBlock _convertDivisionToUCSBlock(STXDivision division) {
    UCSBlock ucsBlock = UCSBlock();
    ucsBlock.beatPerMeasure = division.beatPerMeasure;
    ucsBlock.beatSplit = division.beatSplit;
    ucsBlock.bpm = division.bpm;
    ucsBlock.startTime = division.delay *
        10.0; //startime in STX is in centiseconds so we need to convert to milliseconds

    //Each line for STX for double, half double, and single already correct amount of steps, so no
    //need to do extra logic to set correct line size
    for (var line in division.lines) {
      UCSBlockLine ucsBlockLine = UCSBlockLine();
      for (var step in line.notes) {
        if (step.index > AMNoteType.holdEnd.index) {
          //If notes are any of the special type, just mark it as regular for UCS
          ucsBlockLine.notes.add(AMNoteType.regular);
        } else {
          ucsBlockLine.notes.add(step);
        }
      }

      ucsBlock.lines.add(ucsBlockLine);
    }

    return ucsBlock;
  }

  @override
  Future<List<UCSFile>> convert() async {
    if (_filename.isEmpty) {
      //Can't convert SM with invalid filename

      return List.empty();
    }
    STXFile stxFile = STXFile(_filename);
    await stxFile.intialize();

    //Make UCS from each chart mode
    List<UCSFile> result = [];
    for (var chart in stxFile.getCharts) {
      if (chart.index == ChartIndex.division) {
        //TODO(valius): For division charts, we can make UCS for each variant of each block
        //so we can show every possibility. To be implemented later
      } else {
        //For non-Division modes, we only care about the first division of each block, because UCS does not support
        //multiple divisions. Historically no STX has more than 1 division per block in non-Division modes anyway...
        String mode;
        UCSChartType ucsChartType = UCSChartType.single;
        switch (chart.index) {
          case ChartIndex.practice:
            mode = "practice";
            break;
          case ChartIndex.normal:
            mode = "normal";
            break;
          case ChartIndex.hard:
            mode = "hard";
            break;
          case ChartIndex.crazy:
            mode = "crazy";
            break;
          case ChartIndex.freestyle:
            mode = "freestyle";
            ucsChartType = UCSChartType.double;
            break;
          case ChartIndex.nightmare:
            mode = "nightmare";
            ucsChartType = UCSChartType.double;
            break;
          case ChartIndex.halfDouble:
            mode = "halfdouble";
            ucsChartType = UCSChartType.double;
            break;
          default:
            mode =
                "unknown"; //Unknown if there is somehow a chart index that is outside of the defined ones?
            break;
        }
        String ucsFilename = "${p.withoutExtension(_filename)}-$mode.ucs";
        UCSFile ucsFile = UCSFile(ucsFilename);
        ucsFile.chartType = ucsChartType; //Set chart type based on mode above

        for (var block in chart.getBlocks) {
          if (block.divisions.isEmpty) {
            //Not sure how this happened but stop because this block is past the end of the chart
            break;
          }
          
          //We only care about the first division of the block
          var division = block.divisions[0];
          UCSBlock ucsBlock = _convertDivisionToUCSBlock(division);

          ucsFile.getBlocks.add(ucsBlock);
        }

        result.add(ucsFile);
      }
    }

    return result;
  }

  @override
  String get getFilename {
    return _filename;
  }
}
