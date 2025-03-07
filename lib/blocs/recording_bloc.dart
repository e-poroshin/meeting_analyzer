import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:js/js.dart';
import 'package:js/js_util.dart';

// JavaScript Interop
@JS('startRecording')
external dynamic startRecording();

@JS('stopRecording')
external void stopRecording();

// Events
abstract class RecordingEvent {}

class StartRecording extends RecordingEvent {}

class StopRecording extends RecordingEvent {}

class SendAudioChunk extends RecordingEvent {
  final List<int> chunkBytes;
  final int chunkIndex;
  final int totalChunks;

  SendAudioChunk(this.chunkBytes, this.chunkIndex, this.totalChunks);
}

// States
abstract class RecordingState {}

class RecordingInitial extends RecordingState {}

class RecordingInProgress extends RecordingState {}

class RecordingChunkCreated extends RecordingState {
  final int chunkIndex;
  final int totalChunks;

  RecordingChunkCreated(this.chunkIndex, this.totalChunks);
}

class RecordingChunkUploaded extends RecordingState {
  final int chunkIndex;
  final int totalChunks;

  RecordingChunkUploaded(this.chunkIndex, this.totalChunks);
}

class RecordingError extends RecordingState {
  final String message;

  RecordingError(this.message);
}

class RecordingTranscriptionReceived extends RecordingState {
  final String transcription;

  RecordingTranscriptionReceived(this.transcription);
}

// BLoC
class RecordingBloc extends Bloc<RecordingEvent, RecordingState> {
  String _currentTranscription = '';

  RecordingBloc() : super(RecordingInitial()) {
    on<StartRecording>(_onStartRecording);
    on<StopRecording>(_onStopRecording);
    on<SendAudioChunk>(_onSendAudioChunk);
  }

  @override
  void onTransition(Transition<RecordingEvent, RecordingState> transition) {
    super.onTransition(transition);
    print('Transition: ${transition.currentState} -> ${transition.nextState}');
  }

  Future<void> _onStartRecording(
    StartRecording event,
    Emitter<RecordingState> emit,
  ) async {
    emit(RecordingInProgress());
    try {
      print("Calling startRecording() from Dart"); // Debug log
      final jsChunks = await promiseToFuture(startRecording());
      final List<dynamic> chunks = jsChunks as List<dynamic>;
      final totalChunks = chunks.length;
      print("Received $totalChunks audio chunks from JavaScript."); // Debug log

      for (int i = 0; i < totalChunks; i++) {
        emit(RecordingChunkCreated(i + 1, totalChunks));
        final chunk = chunks[i];
        print("Processing chunk $i"); // Debug log

        // Convert the JavaScript Blob to a Dart Uint8List
        final bytes = await promiseToFuture(
          callMethod(chunk, 'arrayBuffer', []),
        );
        final Uint8List chunkBytes = Uint8List.view(bytes);
        print("Chunk $i converted to Uint8List."); // Debug log

        await _uploadChunk(chunkBytes, i + 1, totalChunks, emit);
      }
    } catch (error) {
      print("Error calling startRecording(): ${error.toString()}"); // Debug log
      emit(RecordingError("Failed to start recording: ${error.toString()}"));
    }
  }

  void _onStopRecording(StopRecording event, Emitter<RecordingState> emit) {
    stopRecording();
  }

  Future<void> _onSendAudioChunk(
    SendAudioChunk event,
    Emitter<RecordingState> emit,
  ) async {
    await _uploadChunk(
      event.chunkBytes,
      event.chunkIndex,
      event.totalChunks,
      emit,
    );
  }

  Future<void> _uploadChunk(
    List<int> chunkBytes,
    int chunkIndex,
    int totalChunks,
    Emitter<RecordingState> emit,
  ) async {
    try {
      print("Uploading chunk $chunkIndex of $totalChunks."); // Debug log
      final uri = Uri.parse("https://api.openai.com/v1/audio/transcriptions");
      var request =
          http.MultipartRequest("POST", uri)
            ..headers["Authorization"] = "Bearer ${dotenv.env['API_KEY']}"
            ..fields["model"] = "whisper-1"
            ..fields["response_format"] = "text"
            ..files.add(
              http.MultipartFile.fromBytes(
                "file",
                chunkBytes,
                filename: "chunk_$chunkIndex.webm",
              ),
            );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      print("Response body: $responseBody"); // Debug log

      if (response.statusCode == 200) {
        print("Chunk $chunkIndex uploaded successfully."); // Debug log
        emit(RecordingChunkUploaded(chunkIndex, totalChunks));
        print("Emitting RecordingTranscriptionReceived state."); // Debug log

        // Append the new response to the current transcription
        _currentTranscription += responseBody;

        emit(RecordingTranscriptionReceived(_currentTranscription));
      } else {
        print(
          "Failed to upload chunk $chunkIndex: ${response.statusCode}",
        ); // Debug log
        emit(
          RecordingError(
            'Failed to upload chunk $chunkIndex: ${response.statusCode}',
          ),
        );
      }
    } catch (error) {
      print(
        "Error uploading chunk $chunkIndex: ${error.toString()}",
      ); // Debug log
      emit(
        RecordingError(
          'Failed to upload chunk $chunkIndex: ${error.toString()}',
        ),
      );
    }
  }
}

// Helper class to convert JS Blob to Dart Uint8List
@JS('Blob')
@staticInterop
class JsBlob {
  external factory JsBlob(List<dynamic> blobParts, [BlobPropertyBag? options]);
}

extension JsBlobExtension on JsBlob {
  external dynamic arrayBuffer();
}

@JS()
@anonymous
class BlobPropertyBag {
  external String get type;

  external factory BlobPropertyBag({String type});
}
