import 'dart:collection';
import 'dart:developer';

import "package:path/path.dart" as p;

import 'package:ucsconvertertool/step_files/andamiro_common.dart';
import 'package:ucsconvertertool/step_files/stx_file.dart';

import '../step_files/ucs_file.dart';
import 'i_converter.dart';

class STXConverter implements IConverter {
  late final String _filename;
  final Map<int, List<UCSBlock>> _mapOfBlocks = HashMap();
  late STXFile _stxFile;
  final List<UCSFile> _outputUCSCharts = [];

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

  void _pathThroughCharts(
      STXChart chart, int blockIndex, int divisionIndex, List<int> pathSoFar) {
    //Mark this division as visited
    pathSoFar.add(divisionIndex);

    if (blockIndex == chart.getBlocks.length - 1) {
      //We are in last block, so end the path here

      //Create chart from the path we just made through the chart possibilities
      _outputUCSCharts.add(createChartFromPath(chart, pathSoFar));
      return;
    }

    //Set up so we go through all divisions in the next block
    STXBlock nextBlock = chart.getBlocks[blockIndex + 1];
    for (int i = 0; i < nextBlock.divisions.length; i++) {
      var pathSoFarCopy = List<int>.from(pathSoFar);    //Pass a copy of the list down to the next function call or you will get mutation issues
      _pathThroughCharts(chart, blockIndex + 1, i, pathSoFarCopy);
    }
  }

  UCSFile createChartFromPath(STXChart chart, List<int> path) {
    String ucsFilename = "${p.withoutExtension(_filename)}-division-variant";
    for (int index in path) {
      ucsFilename += "-${index + 1}"; //Convert from 0 index to 1 index
    }
    ucsFilename += ".ucs";
    UCSFile result = UCSFile(ucsFilename);
    result.chartType = UCSChartType.single; //Division is always single

    //The index is the block index, the value of the element is the division index
    for (int i = 0; i < path.length; i++) {
      UCSBlock? ucsBlock = _mapOfBlocks[i]?[path[i]];

      if (ucsBlock != null) {
        result.getBlocks.add(ucsBlock);
      }
    }

    return result;
  }

  @override
  Future<List<UCSFile>> convert() async {
    if (_filename.isEmpty) {
      //Can't convert SM with invalid filename

      return List.empty();
    }
    _stxFile = STXFile(_filename);
    await _stxFile.intialize();

    //Make UCS from each chart mode
    for (var chart in _stxFile.getCharts) {
      if (chart.index == ChartIndex.division) {
        _mapOfBlocks.clear();

        //Sanity check
        if (chart.getBlocks.isEmpty ||
            chart.getBlocks[0].divisions.length > 1) {
          //This division chart is malformed because there are either no blocks, or block 1 has more than 1 division
          log("Encountered a malformed division chart in STX file");
          continue;
        }

        //Convert all divisions in all blocks to UCS Blocks ahead of time
        for (int i = 0; i < chart.getBlocks.length; i++) {
          var block = chart.getBlocks[i];
          if (block.divisions.isEmpty) {
            //Not sure how this happened but stop because this block is past the end of the chart
            break;
          }

          _mapOfBlocks[i] = List<UCSBlock>.empty(growable: true);
          for (var division in block.divisions) {
            UCSBlock ucsBlock = _convertDivisionToUCSBlock(division);
            _mapOfBlocks[i]?.add(ucsBlock);
          }
        }

        _pathThroughCharts(chart, 0, 0, List<int>.empty(growable: true));
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

        _outputUCSCharts.add(ucsFile);
      }
    }

    return _outputUCSCharts;
  }

  @override
  String get getFilename {
    return _filename;
  }
}
