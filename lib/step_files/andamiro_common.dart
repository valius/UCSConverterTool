enum AMNoteType {
  none,
  regular,
  holdBegin,
  hold,
  holdEnd,
  groove,
  wild,
  aStep,
  bStep,
  cStep,
}

class AndamiroStepLine {
  List<AMNoteType> notes = [];
}