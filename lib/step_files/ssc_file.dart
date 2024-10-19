import 'dart:convert';
import 'dart:core';
import 'dart:developer';
import 'dart:io';
import 'package:ucsconvertertool/step_files/sm_common.dart';

const Set<String> kSSCFileTags = {
  "#BPMS",
  "#STOPS",
  "#OFFSET",
  "#TICKCOUNTS",
  "#NOTEDATA"
};
const Set<String> kSSCChartTags = {
  "#STEPSTYPE",
  "#DIFFICULTY",
  "#BPMS",
  "#STOPS",
  "#OFFSET",
  "#TICKCOUNTS",
  "#METER",
  "#DESCRIPTION",
  "#NOTES"
};

class SSCFileMetaData {
  double offset = 0;
  List<SMValuePair> bpms = [];
  List<SMValuePair> stops = [];
  List<SMValuePair> tickCounts = [];
}

class SSCChart implements ISMChart {
  late SMChartType _chartType;
  late String difficulty;
  late String description;
  late int meter;
  final List<SMMeasure> _measureData = [];
  final SSCFileMetaData metaData = SSCFileMetaData();

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

class SSCFile {
  final List<SSCChart> charts = [];
  final SSCFileMetaData metaData = SSCFileMetaData();

  SMMeasure _currentProcessingMeasure = SMMeasure();
  SSCChart _currentProcessingChart = SSCChart();

  late String _filename;
  SMFileProcessingMode _processingMode = SMFileProcessingMode.tagRead;

  SSCFile(String filename) {
    _filename = filename;
  }

  void _processSSCFileTag(String tag, String tagValue) {
    if (!kSSCFileTags.contains(tag)) {
      //Ignore unsupported tags
      return;
    }

    switch (tag) {
      case "#OFFSET":
        {
          metaData.offset = double.parse(tagValue);
          break;
        }
      case "#BPMS":
        {
          metaData.bpms = processTagValueString(tagValue);
          break;
        }
      case "#STOPS":
        {
          metaData.stops = processTagValueString(tagValue);
          break;
        }
      case "#TICKCOUNTS":
        {
          metaData.tickCounts = processTagValueString(tagValue);
          break;
        }
    }
  }

  void _processSSCChartTag(String tag, String tagValue) {
    switch (tag) {
      case "#STEPSTYPE":
        {
          switch (tagValue) {
            case "pump-double":
              {
                _currentProcessingChart.setChartType = SMChartType.double;
                break;
              }
            case "pump-single":
              {
                _currentProcessingChart.setChartType = SMChartType.single;
                break;
              }
            case "pump-halfdouble":
              {
                _currentProcessingChart.setChartType = SMChartType.halfDouble;
                break;
              }
            case "pump-routine":
              {
                _currentProcessingChart.setChartType = SMChartType.routine;
                break;
              }
            case "pump-couple":
              {
                _currentProcessingChart.setChartType = SMChartType.couple;
                break;
              }
            default:
              {
                _currentProcessingChart.setChartType = SMChartType.invalid;
                break;
              }
          }
          break;
        }
      case "#DIFFICULTY":
        {
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
            case SMChartType.couple:
              chartType = "couple";
              break;
            default:
              break;
          }
          _currentProcessingChart.difficulty = "$chartType-$tagValue";
          break;
        }
      case "#OFFSET":
        {
          _currentProcessingChart.metaData.offset = double.parse(tagValue);
          break;
        }
      case "#BPMS":
        {
          _currentProcessingChart.metaData.bpms =
              processTagValueString(tagValue);
          break;
        }
      case "#STOPS":
        {
          _currentProcessingChart.metaData.stops =
              processTagValueString(tagValue);
          break;
        }
      case "#TICKCOUNTS":
        {
          _currentProcessingChart.metaData.tickCounts =
              processTagValueString(tagValue);
          break;
        }
      case "#METER":
        {
          _currentProcessingChart.meter = int.parse(tagValue);
          break;
        }
      case "#DESCRIPTION":
        {
          _currentProcessingChart.description = tagValue;
          break;
        }
    }
  }

  Future<void> intialize() async {
    try {
      var file = File(_filename);
      Stream<String> fileReadStream = file.openRead().transform(utf8.decoder).transform(const LineSplitter());

      String tagString = "";
      String valueString = "";
      var isLookingForTagValue = false;
      int currentMeasureCompareIndexForRoutine = 0; //Variable only used to help combine routine charts into 1 chart

      await for (var line in fileReadStream) {
        switch (_processingMode) {
          case SMFileProcessingMode.tagRead:
            {
              if (isLookingForTagValue) {
                int indexOfSemicolon = line.indexOf(';');
                if (indexOfSemicolon >= 0) {
                  valueString += line.substring(0, indexOfSemicolon);

                  //Process tag and value
                  _processSSCFileTag(tagString, valueString);

                  //Reset to initial state
                  //Reset tag string and value
                  isLookingForTagValue = false;
                  tagString = "";
                  valueString = "";
                } else {
                  valueString += line;
                }
              } else {
                //Find if line contains a : character
                int indexOfColon = line.indexOf(':');
                int indexOfSemicolon = line.indexOf(';');
                if (indexOfColon >= 0) {
                  tagString += line.substring(0, indexOfColon);

                  if (tagString.contains('#NOTEDATA')) {
                    _processingMode = SMFileProcessingMode.chartTagRead;
                    _currentProcessingChart = SSCChart();

                    //Reset tag string and value
                    isLookingForTagValue = false;
                    tagString = "";
                    valueString = "";
                  } else if (indexOfSemicolon >= 0) {
                    valueString +=
                        line.substring(indexOfColon + 1, indexOfSemicolon);

                    //Process tag and value
                    _processSSCFileTag(tagString, valueString);

                    //Reset to initial state
                    //Reset tag string and value
                    isLookingForTagValue = false;
                    tagString = "";
                    valueString = "";
                  } else {
                    //value is rest of line
                    valueString += line.substring(indexOfColon + 1);
                    isLookingForTagValue = true;
                  }
                } else {
                  tagString += line;
                }
              }

              break;
            }
          case SMFileProcessingMode.chartTagRead:
            {
              if (isLookingForTagValue) {
                int indexOfSemicolon = line.indexOf(';');
                if (indexOfSemicolon >= 0) {
                  valueString += line.substring(0, indexOfSemicolon);

                  //Process tag and value
                  _processSSCChartTag(tagString, valueString);

                  //Reset to initial state
                  //Reset tag string and value
                  isLookingForTagValue = false;
                  tagString = "";
                  valueString = "";
                } else {
                  valueString += line;
                }
              } else {
                //Find if line contains a : character
                int indexOfColon = line.indexOf(':');
                int indexOfSemicolon = line.indexOf(';');
                if (indexOfColon >= 0) {
                  tagString += line.substring(0, indexOfColon);

                  if (tagString.contains('#NOTES')) {
                    _processingMode = SMFileProcessingMode.chartRead;

                    //Reset tag string and value
                    isLookingForTagValue = false;
                    tagString = "";
                    valueString = "";
                  } else if (indexOfSemicolon >= 0) {
                    valueString +=
                        line.substring(indexOfColon + 1, indexOfSemicolon);

                    //Process tag and value
                    _processSSCChartTag(tagString, valueString);

                    //Reset to initial state
                    //Reset tag string and value
                    isLookingForTagValue = false;
                    tagString = "";
                    valueString = "";
                  } else {
                    //value is rest of line
                    valueString += line.substring(indexOfColon + 1);
                    isLookingForTagValue = true;
                  }
                } else {
                  tagString += line;
                }
              }
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
                _currentProcessingChart = SSCChart();
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
