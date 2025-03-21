let mediaRecorder;
let micStream;
let systemStream;
let audioChunks = [];
let audioBuffer = []; // Temporary buffer for accumulating audio data
const MAX_CHUNK_SIZE = 500 * 1024 * 1024; // 500 MB in bytes
let currentBufferSize = 0;
const MIME_TYPE = 'audio/webm';

function requestAudioPermissions() {
    return navigator.mediaDevices.getUserMedia({ audio: true })
        .then(stream => {
            console.log("Microphone permission granted.");
            return stream;
        })
        .catch(error => {
            console.error("Error accessing audio devices: ", error);
            if (error.name === 'NotAllowedError') {
                alert("Permission to access the microphone was denied. Please allow access to record audio.");
            } else {
                alert("An error occurred while trying to access the microphone: " + error.message);
            }
            return Promise.reject(error);
        });
}

function requestSystemAudioPermissions() {
    if (!navigator.mediaDevices.getDisplayMedia) {
        console.warn("getDisplayMedia is not supported in this browser.");
        alert("System audio capture is not supported in this browser.");
        return Promise.reject(new Error("getDisplayMedia is not supported"));
    }

    return navigator.mediaDevices.getDisplayMedia({ audio: true })
        .then(stream => {
            console.log("System audio permission granted.");
            return stream;
        })
        .catch(error => {
            console.error("Error accessing system audio: ", error);
            if (error.name === 'NotAllowedError') {
                alert("Permission to access system audio was denied. Please allow access to record audio.");
            } else if (error.name === 'NotSupportedError') {
                alert("System audio capture is not supported in this browser.");
            } else {
                alert("An error occurred while trying to access system audio: " + error.message);
            }
            return Promise.reject(error);
        });
}

function createChunk() {
    if (audioBuffer.length > 0) {
        const chunkBlob = new Blob(audioBuffer, { type: MIME_TYPE });
        audioChunks.push(chunkBlob);
        audioBuffer = [];
        currentBufferSize = 0;
    }
}

async function startRecording() {
    console.log("startRecording() called.");

    try {
        micStream = await requestAudioPermissions();
        console.log("Microphone stream obtained:", micStream);

        systemStream = await requestSystemAudioPermissions();
        console.log("System audio stream obtained:", systemStream);

        const audioContext = new AudioContext();
        const destination = audioContext.createMediaStreamDestination();

        const micSource = audioContext.createMediaStreamSource(micStream);
        const systemSource = audioContext.createMediaStreamSource(systemStream);

        // Use Merger to divide mic and system sources by separate channels
        const merger = audioContext.createChannelMerger(2);
        micSource.connect(merger, 0, 0);
        systemSource.connect(merger, 0, 1);

        merger.connect(destination);

        // Comment out two lines bellow and comment in Merger code above to avoid dividing channels
        // micSource.connect(destination);
        // systemSource.connect(destination);

        const combinedStream = destination.stream;
        console.log("Combined Stream:", combinedStream);

        combinedStream.getTracks().forEach(track => {
            console.log(`Track kind: ${track.kind}, enabled: ${track.enabled}`);
        });

        mediaRecorder = new MediaRecorder(combinedStream, { mimeType: MIME_TYPE });
        console.log("Combined MediaRecorder created:", mediaRecorder);
        mediaRecorder.start();
        console.log("Combined MediaRecorder started.");

        mediaRecorder.ondataavailable = event => {
            console.log("Data available from MediaRecorder:", event.data);
            audioBuffer.push(event.data);
            currentBufferSize += event.data.size;

            if (currentBufferSize >= MAX_CHUNK_SIZE) {
                createChunk();
            }
        };

        return new Promise(resolve => {
            mediaRecorder.onstop = () => {
                createChunk(); // Create a final chunk from any remaining data
                console.log("Recording stopped, resolving with audio chunks.");
                resolve(audioChunks); // Resolve with the array of fixed-size chunks
            };
        });
    } catch (error) {
        console.error("Error starting recording: ", error);
        return Promise.reject(error);
    }
}

function stopRecording() {
    if (mediaRecorder) {
        mediaRecorder.stop();
    }

    if (micStream) {
        micStream.getTracks().forEach(track => track.stop());
    }

    if (systemStream) {
        systemStream.getTracks().forEach(track => track.stop());
    }
}