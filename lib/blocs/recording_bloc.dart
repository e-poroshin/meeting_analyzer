import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

class SignIn extends RecordingEvent {}

class SignOut extends RecordingEvent {}

class StartRecording extends RecordingEvent {}

class StopRecording extends RecordingEvent {}

class SendAudioChunk extends RecordingEvent {
  final List<int> chunkBytes;
  final int chunkIndex;
  final int totalChunks;

  SendAudioChunk(this.chunkBytes, this.chunkIndex, this.totalChunks);
}

// States
abstract class BaseState {}

class Unauthorized extends BaseState {}

abstract class Authorized extends BaseState {}

class AuthInitial extends Authorized {
  final String userEmail;
  final String accessToken;

  AuthInitial(this.userEmail, this.accessToken);
}

class RecordingInProgress extends Authorized {}

class TranscriptionReceived extends Authorized {
  final String transcription;

  TranscriptionReceived(this.transcription);
}

class RecordingError extends Authorized {
  final String message;

  RecordingError(this.message);
}

class Processing extends Authorized {}

// BLoC
class RecordingBloc extends Bloc<RecordingEvent, BaseState> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        '407746587233-ci1jpdaupb8g5h7ho8854eio5v0egppo.apps.googleusercontent.com',
    scopes: [
      'https://www.googleapis.com/auth/devstorage.read_write',
      'https://www.googleapis.com/auth/cloud-platform',
    ],
  );
  String _currentTranscription = '';
  String? _accessToken;

  RecordingBloc() : super(Unauthorized()) {
    on<StartRecording>(_onStartRecording);
    on<StopRecording>(_onStopRecording);
    on<SendAudioChunk>(_onSendAudioChunk);
    on<SignIn>(_onSignIn);
    on<SignOut>(_onSignOut);

    // Check if user is already signed in
    _checkCurrentUser();
  }

  @override
  void onTransition(Transition<RecordingEvent, BaseState> transition) {
    super.onTransition(transition);
    print('Transition: ${transition.currentState} -> ${transition.nextState}');
  }

  Future<void> _checkCurrentUser() async {
    final account = await _googleSignIn.signInSilently();
    if (account != null) {
      final auth = await account.authentication;
      _accessToken = auth.accessToken;
      emit(AuthInitial(account.email, auth.accessToken!));
    } else {
      emit(Unauthorized());
    }
  }

  Future<void> _onSignIn(SignIn event, Emitter<BaseState> emit) async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        final auth = await account.authentication;
        _accessToken = auth.accessToken;
        emit(AuthInitial(account.email, auth.accessToken!));
      }
    } catch (error) {
      print('Error signing in: ${error.toString()}');
      emit(RecordingError('Failed to sign in: ${error.toString()}'));
    }
  }

  Future<void> _onSignOut(SignOut event, Emitter<BaseState> emit) async {
    await _googleSignIn.signOut();
    _accessToken = null;
    emit(Unauthorized());
  }

  Future<void> _onStartRecording(
    StartRecording event,
    Emitter<BaseState> emit,
  ) async {
    if (_accessToken == null) {
      emit(RecordingError('Please sign in first'));
      return;
    }
    emit(RecordingInProgress());
    try {
      print("Calling startRecording() from Dart"); // Debug log
      final jsChunks = await promiseToFuture(startRecording());
      final List<dynamic> chunks = jsChunks as List<dynamic>;
      final totalChunks = chunks.length;
      print("Received $totalChunks audio chunks from JavaScript."); // Debug log

      for (int i = 0; i < totalChunks; i++) {
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

  void _onStopRecording(StopRecording event, Emitter<BaseState> emit) {
    emit(Processing());
    stopRecording();
  }

  Future<void> _onSendAudioChunk(
    SendAudioChunk event,
    Emitter<BaseState> emit,
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
    Emitter<BaseState> emit,
  ) async {
    try {
      if (_accessToken == null) {
        throw Exception('Not authenticated');
      }

      // Check if the token is expired and refresh if necessary
      await _refreshAccessToken();

      print("Uploading chunk $chunkIndex of $totalChunks.");
      const String projectId = 'triple-kingdom-453012-b0';
      const String bucketName = 'meeting-analyzer-bucket';
      const String location = 'global';
      String filename =
          "${DateTime.now().microsecondsSinceEpoch.toString()}.webm";
      String contentType = "audio/webm";

      String cloudStorageUploadUrl =
          "https://storage.googleapis.com/upload/storage/v1/b/$bucketName/o?uploadType=media&name=$filename";

      final cloudStorageResponse = await http.post(
        Uri.parse(cloudStorageUploadUrl),
        headers: {
          "Authorization": "Bearer $_accessToken",
          "Content-Type": contentType,
        },
        body: chunkBytes,
      );

      if (cloudStorageResponse.statusCode == 200) {
        print(
          "Chunk $chunkIndex uploaded successfully. Response body: ${cloudStorageResponse.body}",
        );

        // Parse the GCS response
        final Map<String, dynamic> gcsResponse = json.decode(
          cloudStorageResponse.body,
        );
        final String gcsUri = "gs://$bucketName/${gcsResponse['name']}";
        print("GCS URI: $gcsUri"); // Debug log

        try {
          final speechToTextUrl =
              'https://speech.googleapis.com/v2/projects/$projectId/locations/$location/recognizers/_:recognize';

          final speechToTextRequestBody = {
            "config": {
              "model": "long",
              "languageCodes": ["en-US", "ru-RU"],
              "autoDecodingConfig": {},
              "features": {
                "enableWordConfidence": false,
                "enableWordTimeOffsets": false,
                "enableAutomaticPunctuation": true,
                "multiChannelMode": "SEPARATE_RECOGNITION_PER_CHANNEL",
              },
            },
            "uri": gcsUri,
          };

          print(
            "Making request to Speech-to-Text API: $speechToTextUrl ; body: $speechToTextRequestBody",
          ); // Debug log

          final speechToTextResponse = await http.post(
            Uri.parse(speechToTextUrl),
            headers: {
              "Authorization": "Bearer $_accessToken",
              "Content-Type": "application/json",
            },
            body: json.encode(speechToTextRequestBody),
          );

          print(
            "speechToText response status: ${speechToTextResponse.statusCode}; body: ${speechToTextResponse.body}",
          );

          if (speechToTextResponse.statusCode == 200) {
            final Map<String, dynamic> results = json.decode(
              speechToTextResponse.body,
            );

            // Create a list to hold results with channelTag and endOffset
            List<Map<String, dynamic>> sortedResults = [];

            // Process the results
            if (results.containsKey('results')) {
              for (var result in results['results']) {
                int channelTag = result['channelTag'];
                String transcript = result['alternatives'][0]['transcript'];
                String endOffsetString = result['resultEndOffset'];

                // Convert endOffset from string to double (remove 's' and parse)
                double endOffset = double.parse(
                  endOffsetString.replaceAll('s', ''),
                );

                // Add the result to the list with channelTag and endOffset
                sortedResults.add({
                  'channelTag': channelTag,
                  'transcript': transcript,
                  'endOffset': endOffset,
                });
              }
            }

            // Sort the results by resultEndOffset
            sortedResults.sort(
              (a, b) => a['endOffset'].compareTo(b['endOffset']),
            );

            // Prepare the final formatted transcription output
            String formattedTranscription = '';
            for (var result in sortedResults) {
              int channel = result['channelTag'];
              String transcript = result['transcript'];

              // Append the transcript to the formatted output
              formattedTranscription += "Speaker $channel: $transcript\n";
            }
            //
            _currentTranscription = formattedTranscription.trim(); //"Done"; //
            emit(TranscriptionReceived(_currentTranscription));
            //
          } else {
            print(
              "Failed with speechToText request $chunkIndex: ${speechToTextResponse.statusCode}, ${speechToTextResponse.body}",
            );
            emit(
              RecordingError(
                'Failed with speechToText request: ${speechToTextResponse.statusCode}, ${speechToTextResponse.body}',
              ),
            );
          }
        } catch (speechToTextError) {
          print(
            "Speech-to-Text API request failed: ${speechToTextError.toString()}",
          );
          emit(
            RecordingError(
              'Speech-to-Text API request failed: ${speechToTextError.toString()}.',
            ),
          );
        }
      } else {
        print(
          "Failed to upload chunk $chunkIndex to Google Cloud Storage: ${cloudStorageResponse.statusCode}, ${cloudStorageResponse.body}",
        );
        emit(
          RecordingError(
            'Failed to upload chunk $chunkIndex to Google Cloud Storage: ${cloudStorageResponse.statusCode}, ${cloudStorageResponse.body}',
          ),
        );
      }
    } catch (error) {
      print("Failed to upload chunk $chunkIndex: ${error.toString()}");
      emit(
        RecordingError(
          'Failed to upload chunk $chunkIndex: ${error.toString()}',
        ),
      );
    }
  }

  Future<void> _refreshAccessToken() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        final auth = await account.authentication;
        _accessToken = auth.accessToken;
      } else {
        throw Exception('Failed to refresh access token: No account found');
      }
    } catch (error) {
      print('Error refreshing access token: ${error.toString()}');
      emit(
        RecordingError('Failed to refresh access token: ${error.toString()}'),
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
