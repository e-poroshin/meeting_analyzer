let mediaRecorder;
let audioChunks = [];

function requestAudioPermissions() {
    return navigator.mediaDevices.getUserMedia({ audio: true })
        .then(stream => {
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
//    if (!navigator.mediaDevices.getDisplayMedia) {
//        console.warn("System audio recording is not supported in this browser. Falling back to microphone only.");
//        return requestAudioPermissions();
//    }

    return navigator.mediaDevices.getDisplayMedia({ video: false, audio: true })
        .then(stream => {
            return stream;
        })
        .catch(error => {
            console.error("Error accessing system audio: ", error);
            alert("An error occurred while trying to access system audio: " + error.message);
            return Promise.reject(error);
        });
}

function startRecording() {
    return requestAudioPermissions()
        .then(micStream => {
            return requestSystemAudioPermissions()
                .then(systemStream => {
                    const combinedStream = new MediaStream([
                        ...micStream.getTracks(),
                        ...systemStream.getTracks()
                    ]);
                    mediaRecorder = new MediaRecorder(combinedStream);
                    mediaRecorder.start();

                    mediaRecorder.ondataavailable = event => {
                        audioChunks.push(event.data);
                    };

                    return new Promise(resolve => {
                        mediaRecorder.onstop = () => {
                            const audioBlob = new Blob(audioChunks, { type: 'audio/wav' });
                            audioChunks = [];
                            resolve(audioBlob);
                        };
                    });
                });
        })
        .catch(error => {
            return Promise.reject(error);
        });
}

function stopRecording() {
    if (mediaRecorder) {
        mediaRecorder.stop();
    }
}