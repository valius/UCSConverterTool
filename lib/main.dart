import 'package:flutter/material.dart';
import 'package:ucsconvertertool/ui/convert_view.dart';

void main() {
  runApp(const UCSConverterTool());
}

class UCSConverterTool extends StatelessWidget {
  const UCSConverterTool({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UCS Converter Tool',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ConvertView(title: 'Convert to UCS'),
    );
  }
}

