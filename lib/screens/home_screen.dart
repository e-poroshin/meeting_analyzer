import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/recording_bloc.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Meeting Analyzer')),
      body: BlocProvider(
        create: (context) => RecordingBloc(),
        child: RecordingControls(),
      ),
    );
  }
}

class RecordingControls extends StatelessWidget {
  const RecordingControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // BlocBuilder<RecordingBloc, BaseState>(
            //   builder: (context, state) {
            //     if (state is RecordingError) {
            //       return Text(
            //         state.message,
            //         style: TextStyle(color: Colors.red, fontSize: 24),
            //       );
            //     }
            //     // if (state is Authorized) {
            //       return Column(
            //         children: [
            //           // Text(
            //           //   'Signed in',
            //           //   style: TextStyle(fontSize: 16, color: Colors.green),
            //           // ),
            //           // SizedBox(height: 10),
            //           ElevatedButton(
            //             onPressed: () {
            //               context.read<RecordingBloc>().add(SignOut());
            //             },
            //             child: Text('Sign Out'),
            //           ),
            //         ],
            //       );
            //     // }
            //     // final bool isUnauthorized = state is Unauthorized;
            //     // return ElevatedButton(
            //     //   onPressed: () {
            //     //     isUnauthorized
            //     //         ? context.read<RecordingBloc>().add(SignIn())
            //     //         : null;
            //     //   },
            //     //   child: Text('Sign In with Google'),
            //     // );
            //   },
            // ),
            SizedBox(height: 20),
            BlocBuilder<RecordingBloc, BaseState>(
              builder: (context, state) {
                final bool isReadyToRecord =
                    state is Authorized &&
                    state is! RecordingInProgress &&
                    state is! Processing;
                final bool isRecording = state is RecordingInProgress;
                var stateText = switch (state) {
                  RecordingInProgress _ => 'Recording...',
                  Uploading _ => 'Uploading',
                  Processing _ => 'Processing',
                  _ => 'Not Recording',
                };
                return Column(
                  children: [
                    Text(stateText, style: TextStyle(fontSize: 24)),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed:
                          // isReadyToRecord ?
                          () => context.read<RecordingBloc>().add(
                            StartRecording(),
                          ),
                      // : null
                      child: Text('Start Recording'),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed:
                          // isRecording ?
                          () => context.read<RecordingBloc>().add(
                            StopRecording(),
                          ),
                      // : null
                      child: Text('Stop Recording'),
                    ),
                  ],
                );
              },
            ),
            BlocBuilder<RecordingBloc, BaseState>(
              builder: (context, state) {
                if (state is TranscriptionReceived) {
                  return Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      state.transcription,
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }
                return Container();
              },
            ),
          ],
        ),
      ),
    );
  }
}
