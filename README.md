# Meeting Analyzer

Meeting Analyzer is a web application built with Flutter that allows users to record audio and transcribe it using the OpenAI Whisper API.

## Features

- Record audio from the microphone and system audio of the selected web tab.
- Upload audio chunks to the OpenAI Whisper API for transcription.
- Display the transcribed text.

## Getting Started

### Prerequisites

- Flutter SDK
- Dart SDK

### Installation

1. Clone the repository:

   ```sh
   git clone https://github.com/e-poroshin/meeting_analyzer.git
   cd meeting_analyzer
   ```

2. Install dependencies:

   ```sh
   flutter pub get
   ```

3. Create a `.env` file in the root directory and add your OpenAI API key:

   ```sh
   API_KEY=your_openai_api_key
   ```

4. Ensure the `.env` file is listed in the `assets` section of `pubspec.yaml`:

   ```yaml
   flutter:
     assets:
       - .env
   ```

### Running the Application

To run the application, use the following command:

```sh
flutter run -d chrome
```

## Note

To use this project from the repository, you must add your own API key to the `.env` file as shown in the installation steps.
