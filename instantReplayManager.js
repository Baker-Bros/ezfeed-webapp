// Instant Replay Management
class InstantReplayManager {
    constructor() {
        this.mediaRecorder = null;
        this.chunks = [];
        this.maxChunks = 120;
        this.isRecording = false;
        this.replayVideo = document.getElementById('replay-video');
        this.replayModal = document.getElementById('replay-modal');
        this.closeModal = document.getElementById('close-modal');
        this.duration = 0;
        this.setupEventListeners();
    }

    setupEventListeners() {
        // Set up close modal button
        this.closeModal.addEventListener('click', () => {
            this.hideReplay();
        });

        // Close modal when clicking outside
        this.replayModal.addEventListener('click', (event) => {
            if (event.target === this.replayModal) {
                this.hideReplay();
            }
        });

        // Close modal with Escape key
        document.addEventListener('keydown', (event) => {
            if (event.key === 'Escape' && this.replayModal.style.display === 'block') {
                this.hideReplay();
            }
        });
    }

    startRecording(stream) {
        if (this.isRecording) return;
        
        this.isRecording = true;
        this.chunks = [];
        this.duration = 0;
        this.showRecordingIndicator();
        
        // Create main recorder for regular chunks
        this.mediaRecorder = new MediaRecorder(stream, {
            mimeType: 'video/webm;codecs=vp8'
        });

        // Handle data from main recorder
        this.mediaRecorder.ondataavailable = (event) => {
            if (event.data.size > 0) {
                this.chunks.push(event.data);
                this.duration += 1;
                if (this.chunks.length > this.maxChunks) {
                    this.chunks = this.chunks.slice(0, 1).concat(this.chunks.slice(-this.maxChunks));
                }
            }
        };

        this.mediaRecorder.start(1000);
    }

    stopRecording() {
        if (this.mediaRecorder && this.isRecording) {
            this.mediaRecorder.stop();
            this.isRecording = false;
            this.hideRecordingIndicator();
            console.log('Instant replay recording stopped');
        }
    }

    showRecordingIndicator() {
        const indicator = document.getElementById('recording-indicator');
        if (indicator) {
            indicator.style.display = 'block';
        }
    }

    hideRecordingIndicator() {
        const indicator = document.getElementById('recording-indicator');
        if (indicator) {
            indicator.style.display = 'none';
        }
    }

    playReplay(duration = 15) {
        if (this.chunks.length === 0) {
            alert('No replay data available');
            return;
        }

        // Ensure duration doesn't exceed available chunks
        const availableDuration = Math.min(duration, this.chunks.length);
        
        // Create a blob from combined chunks
        const blob = new Blob(this.chunks, { type: 'video/webm' });
        const url = URL.createObjectURL(blob);
                
        this.replayVideo.src = url;
        this.replayModal.style.display = 'block';
        
        // Calculate start time based on requested duration
        if(this.duration > availableDuration) {
            this.replayVideo.currentTime = this.duration - availableDuration;
        } else {
            this.replayVideo.currentTime = 0;
        }
        this.replayVideo.play().catch(err => {
            console.error('Error playing replay:', err);
        });

        // Clean up URL when video ends
        this.replayVideo.onended = () => {
            URL.revokeObjectURL(url);
            this.hideReplay();
        };
    }

    hideReplay() {
        this.replayModal.style.display = 'none';
        if (this.replayVideo.src) {
            URL.revokeObjectURL(this.replayVideo.src);
            this.replayVideo.src = '';
        }
    }

    cleanup() {
        this.stopRecording();
        
        this.chunks = [];
        this.duration = 0;
        if (this.replayVideo.src) {
            URL.revokeObjectURL(this.replayVideo.src);
        }
    }
} 