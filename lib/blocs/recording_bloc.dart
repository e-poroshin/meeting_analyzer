import 'package:flutter_bloc/flutter_bloc.dart';

// Events
abstract class RecordingEvent {}

class StartRecording extends RecordingEvent {}

class StopRecording extends RecordingEvent {}

// States
abstract class RecordingState {}

class RecordingInitial extends RecordingState {}

class RecordingInProgress extends RecordingState {}

// BLoC
class RecordingBloc extends Bloc<RecordingEvent, RecordingState> {
  RecordingBloc() : super(RecordingInitial());

  Stream<RecordingState> mapEventToState(RecordingEvent event) async* {
    if (event is StartRecording) {
      yield RecordingInProgress();
      // Add logic to start recording
    } else if (event is StopRecording) {
      yield RecordingInitial();
      // Add logic to stop recording
    }
  }
}