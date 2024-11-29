import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ucsconvertertool/generators/converter_generator.dart';
import "package:path/path.dart" as p;
import 'package:ucsconvertertool/helpers/path_helpers.dart';
import 'package:ucsconvertertool/step_files/ucs_file.dart';

class ConvertView extends StatefulWidget {
  const ConvertView({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<ConvertView> createState() => _ConvertViewState();
}

class _ConvertViewState extends State<ConvertView> {
  final _controller = TextEditingController();
  final ScrollController _interfaceElementsScrollController =
      ScrollController();
  final ScrollController _textScrollController = ScrollController();
  final List<String> _supportedExtensions = ['sm', 'ssc', 'stx'];
  List<String> _outputStrings = ["Idle"];
  List<TextStyle> _outputTextStyles = [const TextStyle(color: Colors.black)];

  bool _textMustScroll = false;
  bool _buttonsEnabled = true;
  bool _cancelQueued = false;

  void _openFileDialog() async {
    setState(() {
      _buttonsEnabled = false;
    });

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _supportedExtensions,
    );

    if (result != null) {
      setState(() {
        _controller.text = result.files.single.path!;
      });
    }

    setState(() {
      _buttonsEnabled = true;
    });
  }

  void _openDirectoryDialog() async {
    setState(() {
      _buttonsEnabled = false;
    });

    String? result = await FilePicker.platform.getDirectoryPath();

    if (result != null) {
      setState(() {
        _controller.text = result;
      });
    }

    setState(() {
      _buttonsEnabled = true;
    });
  }

  void _textScrollToEnd() {
    _textScrollController.animateTo(
        _textScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut);
  }

  void _convertfile() async {
    if (_controller.text.isEmpty) {
      setState(() {
        _outputStrings = ["No file or directory selected!"];
        _outputTextStyles = [const TextStyle(color: Colors.black)];
      });
      return;
    }
    setState(() {
      _buttonsEnabled = false;
      _outputStrings = [
        "Generating list of supported files from input ${_controller.text}...\n"
      ];
      _outputTextStyles = [const TextStyle(color: Colors.black)];
    });

    var listFiles =
        await getListOfFilesFromPath(_controller.text, _supportedExtensions);

    for (var file in listFiles) {
      if (_cancelQueued) {
        //Drop out early if a cancel has been queued
        break;
      }

      try {
        setState(() {
          _outputStrings.add("Generating UCS files from $file...");
          _outputTextStyles.add(const TextStyle(color: Colors.black));
        });

        var converter = ConverterGenerator.createConverter(file);
        List<UCSFile> ucsFiles = await converter.convert();

        List<Future<void>> outputFutures = [];
        String resultString = "Generated ";
        for (var ucsFile in ucsFiles) {
          outputFutures.add(ucsFile.outputToFile());

          String filenameOnly = p.basename(ucsFile.getFilename);
          resultString += "$filenameOnly, ";
        }

        resultString += "in the folder ${p.dirname(_controller.text)}\n";

        await Future.wait(outputFutures);

        setState(() {
          _outputStrings.add(resultString);
          _outputTextStyles
              .add(const TextStyle(color: Color.fromARGB(255, 56, 129, 57)));
          _textMustScroll = true;
        });
      } catch (e) {
        setState(() {
          _outputStrings.add("Ran into error: $e");
          _outputTextStyles
              .add(const TextStyle(color: Colors.red));
          _textMustScroll = true;
        });
      }
    }

    if (_cancelQueued) {
      setState(() {
        _outputStrings.add("Conversion stopped by user.");
        _outputTextStyles.add(const TextStyle(color: Colors.red));
        _textMustScroll = true;
        _cancelQueued = false;
      });
    } else {
      setState(() {
        _outputStrings.add("Conversion completed.");
        _outputTextStyles.add(const TextStyle(color: Colors.black));
        _textMustScroll = true;
      });
    }

    setState(() {
      _buttonsEnabled = true;
    });
  }

  void _cancelConversion() async {
    _cancelQueued = true;
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.

    //Auto scroll text if needed
    if (_textMustScroll) {
      //You must have the text scroll after the UI is built and rendered to properly work
      WidgetsBinding.instance.addPostFrameCallback((_) => _textScrollToEnd());
      _textMustScroll = false;
    }

    return Scaffold(
        appBar: AppBar(
          // TRY THIS: Try changing the color here to a specific color (to
          // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
          // change color while the other colors stay the same.
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text(widget.title),
        ),
        body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Flexible(
                child: Scrollbar(
                  thumbVisibility: true,
                  controller: _interfaceElementsScrollController,
                  child: ListView(
                    controller: _interfaceElementsScrollController,
                    padding: const EdgeInsets.all(8),
                    children: <Widget>[
                      Text(
                        'Choose a file or directory',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          border: UnderlineInputBorder(),
                          hintText: 'No file or directory selected',
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8)),
                                side: BorderSide(
                                  color: Colors.black,
                                  width: 5,
                                ),
                              ),
                            ),
                            onPressed: _buttonsEnabled ? _openFileDialog : null,
                            child: const Text('Open File'),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8)),
                                side: BorderSide(
                                  color: Colors.black,
                                  width: 5,
                                ),
                              ),
                            ),
                            onPressed:
                                _buttonsEnabled ? _openDirectoryDialog : null,
                            child: const Text('Open Folder'),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8)),
                                side: BorderSide(
                                  color: Colors.black,
                                  width: 5,
                                ),
                              ),
                            ),
                            onPressed: _buttonsEnabled ? _convertfile : null,
                            child: const Text('Convert'),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8)),
                                side: BorderSide(
                                  color: Colors.black,
                                  width: 5,
                                ),
                              ),
                            ),
                            onPressed: !_buttonsEnabled
                                ? _cancelConversion
                                : null, //We only want cancel active when conversion is underway
                            child: const Text('Cancel'),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              Flexible(
                  child: FractionallySizedBox(
                      heightFactor: 1.0,
                      child: Scrollbar(
                          thumbVisibility: true,
                          controller: _textScrollController,
                          child: ListView.builder(
                              controller: _textScrollController,
                              padding: const EdgeInsets.all(0),
                              itemCount: _outputStrings.length,
                              itemBuilder: (BuildContext context, int index) {
                                return Text(
                                  _outputStrings[index],
                                  style: _outputTextStyles[index],
                                );
                              }))))
            ]));
  }
}
