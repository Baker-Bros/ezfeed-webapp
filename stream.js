// Function to initialize the application
function initializeApp() {
    // DOM Elements
    const video = document.getElementById('video');
    const whepUrl = 'http://ezfeed.local:8000/whep';

    if (!video) {
        console.log('Video element not found, waiting for DOM to be ready...');
        return;
    }

    // Initialize the application
    const webRTCManager = new WebRTCManager(whepUrl);

    // Make webRTCManager globally available for HTML button access
    window.webRTCManager = webRTCManager;

    // Set up connection state change callback
    webRTCManager.onConnectionStateChange = updateReplayButtonsVisibility;

    // Function to update replay buttons visibility
    function updateReplayButtonsVisibility() {
        const replayButtons = document.getElementById('replay-buttons');
        if (replayButtons) {
            if (webRTCManager.isConnected()) {
                replayButtons.classList.remove('hidden');
            } else {
                replayButtons.classList.add('hidden');
            }
        }
    }

    // Set up page visibility listener
    document.addEventListener('visibilitychange', () => {
        webRTCManager.onVisibilityChange();
        updateReplayButtonsVisibility();
    });

    // Set up keyboard shortcuts
    document.addEventListener('keydown', (event) => {
        // R key for instant replay (only if modal is not open)
        if (event.key.toLowerCase() === 'r' && !event.ctrlKey && !event.altKey && !event.metaKey) {
            const modal = document.getElementById('replay-modal');
            if (modal && modal.style.display !== 'block') {
                event.preventDefault();
                webRTCManager.getReplayManager().playReplay(15); // Default to 15 seconds
            }
        }
    });

    // Start the stream when the page loads
    webRTCManager.startStream();

    // Initial visibility check
    updateReplayButtonsVisibility();
}

// Wait for DOM to be ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeApp);
} else {
    // DOM is already ready, but wait for video player to be created
    window.addEventListener('videoPlayerReady', initializeApp);
    
    // Also try to initialize immediately in case the event was already fired
    setTimeout(initializeApp, 0);
} 