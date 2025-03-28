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
            BlocBuilder<RecordingBloc, RecordingState>(
              builder: (context, state) {
                if (state is RecordingError) {
                  return Text(
                    state.message,
                    style: TextStyle(color: Colors.red, fontSize: 24),
                  );
                }
                return Text(
                  state is RecordingInProgress ? 'Recording...' : 'Not Recording',
                  style: TextStyle(fontSize: 24),
                );
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                context.read<RecordingBloc>().add(StartRecording());
              },
              child: Text('Start Recording'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                context.read<RecordingBloc>().add(StopRecording());
              },
              child: Text('Stop Recording'),
            ),
            BlocBuilder<RecordingBloc, RecordingState>(
              builder: (context, state) {
                if (state is RecordingTranscriptionReceived) {
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
