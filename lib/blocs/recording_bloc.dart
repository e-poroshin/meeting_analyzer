import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:js/js.dart';
import 'package:js/js_util.dart';

@JS('startRecording')
external dynamic startRecording();

@JS('stopRecording')
external void stopRecording();

// Events
abstract class RecordingEvent {}

class StartRecording extends RecordingEvent {}

class StopRecording extends RecordingEvent {}

// States
abstract class RecordingState {}

class RecordingInitial extends RecordingState {}

class RecordingInProgress extends RecordingState {}

class RecordingError extends RecordingState {
  final String message;

  RecordingError(this.message);
}

// BLoC
class RecordingBloc extends Bloc<RecordingEvent, RecordingState> {
  RecordingBloc() : super(RecordingInitial()) {
    on<StartRecording>(_onStartRecording);
    on<StopRecording>(_onStopRecording);
  }

  Future<void> _onStartRecording(StartRecording event, Emitter<RecordingState> emit) async {
    emit(RecordingInProgress());
    try {
      await promiseToFuture(startRecording());
    } catch (error) {
      emit(RecordingError("Failed to start recording: ${error.toString()}"));
    }
  }

  void _onStopRecording(StopRecording event, Emitter<RecordingState> emit) {
    emit(RecordingInitial());
    stopRecording();
  }
}