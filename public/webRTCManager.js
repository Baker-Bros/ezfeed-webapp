// WebRTC Connection Management
class WebRTCManager {
    constructor(whepUrl) {
        this.whepUrl = whepUrl;
        this.pc = null;
        this.reconnectAttempts = 0;
        this.reconnectTimer = null;
        this.isConnecting = false;
        this.hasStream = false;
        this.isPageVisible = !document.hidden;
        this.replayManager = new InstantReplayManager();
        this.video = document.getElementById('video');
        this.onConnectionStateChange = null; // Callback for connection state changes
    }

    async startStream() {
        if (this.isConnecting) return;
        this.isConnecting = true;

        try {
            this.cleanupConnection();
            await this.setupPeerConnection();
            await this.createOffer();
            console.log('WebRTC connection established');
        } catch (err) {
            console.error('WebRTC error:', err);
            this.handleConnectionError();
        } finally {
            this.isConnecting = false;
        }
    }

    cleanupConnection() {
        if (this.pc) {
            this.pc.close();
            this.pc = null;
        }
        if (this.reconnectTimer) {
            clearTimeout(this.reconnectTimer);
            this.reconnectTimer = null;
        }
        this.hasStream = false;
        this.video.srcObject = null;
        this.replayManager.cleanup();
    }

    async setupPeerConnection() {
        this.pc = new RTCPeerConnection();
        this.pc.addTransceiver('video', { direction: 'recvonly' });

        this.pc.ontrack = (event) => {
            if (!this.video.srcObject) {
                console.log('Received video track');
                this.video.srcObject = event.streams[0];
                this.hasStream = true;
                this.resetReconnectState();
                
                // Start recording for instant replay
                this.replayManager.startRecording(event.streams[0]);
                
                // Notify UI of connection state change
                if (this.onConnectionStateChange) {
                    this.onConnectionStateChange();
                }
            }
        };

        this.pc.onconnectionstatechange = () => {
            console.log('Connection state:', this.pc.connectionState);
            if (this.pc.connectionState === 'failed' || this.pc.connectionState === 'disconnected') {
                this.handleConnectionError();
            }
            // Notify UI of connection state change
            if (this.onConnectionStateChange) {
                this.onConnectionStateChange();
            }
        };

        this.pc.oniceconnectionstatechange = () => {
            console.log('ICE connection state:', this.pc.iceConnectionState);
            if (this.pc.iceConnectionState === 'failed' || this.pc.iceConnectionState === 'disconnected') {
                this.handleConnectionError();
            }
            // Notify UI of connection state change
            if (this.onConnectionStateChange) {
                this.onConnectionStateChange();
            }
        };
    }

    async createOffer() {
        const offer = await this.pc.createOffer();
        await this.pc.setLocalDescription(offer);

        // Create AbortController with 2 second timeout
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 2000);

        try {
            const response = await fetch(this.whepUrl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/sdp',
                    'Accept': 'application/sdp'
                },
                body: offer.sdp,
                signal: controller.signal
            });

            clearTimeout(timeoutId);

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            const answerSDP = await response.text();
            await this.pc.setRemoteDescription({ type: 'answer', sdp: answerSDP });
        } catch (error) {
            clearTimeout(timeoutId);
            if (error.name === 'AbortError') {
                throw new Error('Request timeout after 2 seconds');
            }
            throw error;
        }
    }

    handleConnectionError() {
        console.log('Connection lost, attempting to reconnect...');
        this.hasStream = false;
        this.video.srcObject = null;
        this.replayManager.cleanup(); // Cleanup replay on connection error
        this.reconnectAttempts++;
        this.scheduleReconnect();
    }

    scheduleReconnect() {
        if (this.reconnectTimer) {
            clearTimeout(this.reconnectTimer);
        }
        
        this.reconnectTimer = setTimeout(() => {
            // Only attempt reconnection if page is visible
            if (!document.hidden) {
                console.log(`Attempting to reconnect... (attempt ${this.reconnectAttempts + 1})`);
                this.startStream();
            } else {
                console.log('Page not visible, skipping reconnection attempt');
                // Schedule another check when page becomes visible
                this.scheduleReconnect();
            }
        }, 0);
    }

    resetReconnectState() {
        this.reconnectAttempts = 0;
        if (this.reconnectTimer) {
            clearTimeout(this.reconnectTimer);
            this.reconnectTimer = null;
        }
    }

    // Handle page visibility changes
    onVisibilityChange() {
        const wasVisible = this.isPageVisible;
        this.isPageVisible = !document.hidden;
        
        if (!wasVisible && this.isPageVisible) {
            // Page became visible, check if we need to reconnect
            console.log('Page became visible, checking connection status');
            if (!this.hasStream && !this.isConnecting) {
                console.log('No active stream, attempting to reconnect');
                this.startStream();
            }
        } else if (wasVisible && !this.isPageVisible) {
            // Page became hidden, clear any pending reconnection attempts
            console.log('Page became hidden, pausing reconnection attempts');
            if (this.reconnectTimer) {
                clearTimeout(this.reconnectTimer);
                this.reconnectTimer = null;
            }
        }
    }

    // Getter for replay manager to allow external access
    getReplayManager() {
        return this.replayManager;
    }

    // Check if the connection is active and streaming
    isConnected() {
        return this.hasStream && this.pc && this.pc.connectionState === 'connected';
    }
} 