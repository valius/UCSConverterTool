import 'dart:convert';
import 'dart:core';
import 'dart:developer';
import 'dart:io';

import 'package:ucsconvertertool/step_files/sm_common.dart';

const Set<String> kSMFileTags = {"#BPMS", "#STOPS", "#OFFSET", "#NOTES"};

enum SMChartTagOrder { type, steps, difficultyName, level, unused }

class SMChart implements ISMChart {
  SMChartTagOrder order = SMChartTagOrder.type;
  late SMChartType _chartType;
  String difficulty = "";
  late int level;
  final List<SMMeasure> _measureData = [];

  @override
  SMChartType get getChartType {
    return _chartType;
  }

  @override
  set setChartType(SMChartType chartType) {
    _chartType = chartType;
  }

  @override
  List<SMMeasure> get getMeasureData {
    return _measureData;
  }
}

class SMFileMetadata {
  late double offset;
  late List<SMValuePair> bpms;
  late List<SMValuePair> stops;
}

class SMFile {
  final List<SMChart> charts = [];
  final SMFileMetadata metadata = SMFileMetadata();

  SMChart _currentProcessingChart = SMChart();
  SMMeasure _currentProcessingMeasure = SMMeasure();
  late String _filename;
  SMFileProcessingMode _processingMode = SMFileProcessingMode.tagRead;

  SMFile(String filename) {
    _filename = filename;
  }

  void _processSMFileTag(String tag, String tagValue) {
    if (!kSMFileTags.contains(tag)) {
      //Ignore unsupported tags
      return;
    }

    switch (tag) {
      case "#OFFSET":
        {
          metadata.offset = double.parse(tagValue);
          break;
        }
      case "#BPMS":
        {
          metadata.bpms = processTagValueString(tagValue);
          break;
        }
      case "#STOPS":
        {
          metadata.stops = processTagValueString(tagValue);
          break;
        }
    }
  }

  void _processChartTagLine(String inLine) {
    if (inLine.isEmpty) {
      //Skip empty chart tag line
      return;
    }

    String trimmedLine = inLine.trim();
    if (_currentProcessingChart.order == SMChartTagOrder.type) {
      if (trimmedLine == "pump-double:") {
        _currentProcessingChart.setChartType = SMChartType.double;
      } else if (trimmedLine == "pump-single:") {
        _currentProcessingChart.setChartType = SMChartType.single;
      } else if (trimmedLine == "pump-halfdouble:") {
        _currentProcessingChart.setChartType = SMChartType.halfDouble;
      } else if (trimmedLine == "pump-routine:") {
        _currentProcessingChart.setChartType = SMChartType.routine;
      } else {
        _currentProcessingChart.setChartType = SMChartType.invalid;
      }
    } else if (_currentProcessingChart.order ==
        SMChartTagOrder.difficultyName) {
      int indexOfColon = trimmedLine.indexOf(':');
      String result = trimmedLine;
      if (indexOfColon > 0) {
        result = trimmedLine.substring(0, indexOfColon);
      }

      String chartType = "Unknown";
      switch (_currentProcessingChart.getChartType) {
        case SMChartType.single:
          chartType = "single";
          break;
        case SMChartType.double:
          chartType = "double";
          break;
        case SMChartType.halfDouble:
          chartType = "halfdouble";
          break;
        case SMChartType.routine:
          chartType = "routine";
          break;
        default:
          break;
      }
      _currentProcessingChart.difficulty = '$chartType-$result';
    } else if (_currentProcessingChart.order == SMChartTagOrder.level) {
      int indexOfColon = trimmedLine.indexOf(":");
      String result = trimmedLine;
      if (indexOfColon > 0) {
        result = trimmedLine.substring(0, indexOfColon);
      }
      _currentProcessingChart.level = int.parse(result);
    } else if (_currentProcessingChart.order == SMChartTagOrder.unused) {
      //End of tag section, change processing mode
      _processingMode = SMFileProcessingMode.chartRead;

      return;
    }

    _currentProcessingChart.order =
        SMChartTagOrder.values[_currentProcessingChart.order.index + 1];
  }

  Future<void> intialize() async {
    try {
      var file = File(_filename);
      Stream<String> fileReadStream = file
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      String tagString = "";
      String valueString = "";
      var isLookingForTagValue = false;
      int currentMeasureCompareIndexForRoutine =
          0; //Variable only used to help combine routine charts into 1 chart

      await for (var line in fileReadStream) {
        switch (_processingMode) {
          case SMFileProcessingMode.tagRead:
            {
              bool shouldChangeMode;
              (
                shouldChangeMode: shouldChangeMode,
                isLookingForTagValue: isLookingForTagValue,
                tagString: tagString,
                valueString: valueString
              ) = processTag(line, tagString, valueString, isLookingForTagValue,
                  '#NOTES', _processSMFileTag);
              if (shouldChangeMode) {
                _processingMode = SMFileProcessingMode.chartTagRead;
                _currentProcessingChart = SMChart();
              }
              break;
            }
          case SMFileProcessingMode.chartTagRead:
            {
              _processChartTagLine(line);
              break;
            }
          case SMFileProcessingMode.chartRead:
            {
              var result = processChartLine(line, _currentProcessingMeasure);
              _currentProcessingMeasure = result.measure;
              _processingMode = result.currentProcessingMode;

              if (result.measureDidEnd) {
                _currentProcessingChart.getMeasureData
                    .add(_currentProcessingMeasure);
                _currentProcessingMeasure = SMMeasure();
              }
              if (result.chartDidEnd) {
                charts.add(_currentProcessingChart);
              }
              break;
            }
          case SMFileProcessingMode.routineChartRead:
            {
              var result = processSecondRoutineChartLine(
                  line,
                  currentMeasureCompareIndexForRoutine,
                  _currentProcessingMeasure,
                  _currentProcessingChart
                      .getMeasureData[currentMeasureCompareIndexForRoutine]);

              _currentProcessingMeasure = result.measure;
              _processingMode = result.currentProcessingMode;

              if (result.measureDidEnd) {
                _currentProcessingChart
                        .getMeasureData[currentMeasureCompareIndexForRoutine] =
                    _currentProcessingMeasure;
                currentMeasureCompareIndexForRoutine++;
                _currentProcessingMeasure = SMMeasure();
              }
              if (result.routineChartDidEnd) {
                //More routine charts are around, combine more, so reset index
                currentMeasureCompareIndexForRoutine = 0;
              } else if (result.chartDidEnd) {
                currentMeasureCompareIndexForRoutine = 0;
                charts.add(_currentProcessingChart);
                _currentProcessingChart = SMChart();
              }
              break;
            }
          default:
            {
              break;
            }
        }
      }
    } catch (e) {
      log("Encountered error $e");
    }
  }
}
