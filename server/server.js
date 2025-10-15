// server.js
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const axios = require('axios');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

app.use(cors());
app.use(express.json());

// Store active call transcripts
const activeCalls = new Map();

// Free STT APIs (No installation required)
class FreeSTTService {
  
  // Method 1: Use browser's Speech Recognition API via client-side (we'll handle in Flutter)
  // Method 2: Use free online STT services
  
  static async transcribeWithGoogle(audioBase64, sampleRate = 16000) {
    try {
      // Note: This is a simplified approach - for production use proper Google Speech API
      // This is just for demonstration
      return "Transcription placeholder - use client-side STT";
    } catch (error) {
      console.error('Google STT error:', error);
      return null;
    }
  }
}

// WebSocket connections for real-time communication
io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);

  // Join a call room
  socket.on('join-call', (data) => {
    const { callId, userId, userName } = data;
    
    socket.join(callId);
    console.log(`User ${userName} (${userId}) joined call ${callId}`);
    
    // Initialize call data if not exists
    if (!activeCalls.has(callId)) {
      activeCalls.set(callId, {
        transcripts: [],
        participants: new Map(),
        startTime: new Date()
      });
    }
    
    const callData = activeCalls.get(callId);
    callData.participants.set(userId, { userName, socketId: socket.id });
    
    // Send existing transcripts to new participant
    socket.emit('call-transcripts', callData.transcripts);
  });

  // Receive transcript from client (client-side STT)
  socket.on('transcript-update', (data) => {
    const { callId, userId, transcript, isFinal } = data;
    
    if (!activeCalls.has(callId)) return;

    const callData = activeCalls.get(callId);
    const userData = callData.participants.get(userId);
    
    if (!userData) return;

    const transcriptEntry = {
      id: Date.now().toString(),
      userId,
      userName: userData.userName,
      text: transcript,
      timestamp: new Date().toISOString(),
      isFinal
    };

    // Add to transcripts
    callData.transcripts.push(transcriptEntry);
    
    // Broadcast to all participants in the call
    io.to(callId).emit('new-transcript', transcriptEntry);
    
    console.log(`Transcript [${callId}]: ${userData.userName} - ${transcript}`);
  });

  // Leave call
  socket.on('leave-call', (data) => {
    const { callId, userId } = data;
    
    if (activeCalls.has(callId)) {
      const callData = activeCalls.get(callId);
      callData.participants.delete(userId);
      
      // Clean up if no participants
      if (callData.participants.size === 0) {
        activeCalls.delete(callId);
      }
    }
    
    socket.leave(callId);
    console.log(`User ${userId} left call ${callId}`);
  });

  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
  });
});

// REST API endpoints
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', activeCalls: activeCalls.size });
});

app.get('/api/transcripts/:callId', (req, res) => {
  const callId = req.params.callId;
  const callData = activeCalls.get(callId);
  
  if (callData) {
    res.json({
      callId,
      transcripts: callData.transcripts,
      participantCount: callData.participants.size
    });
  } else {
    res.json({ callId, transcripts: [], participantCount: 0 });
  }
});

// Save transcripts to file (free storage)
app.post('/api/save-transcript', (req, res) => {
  const { callId, transcripts } = req.body;
  
  try {
    // In a real app, you'd save to database
    // For free solution, we'll just return success
    console.log(`Saving transcript for call ${callId}:`, transcripts.length, 'entries');
    
    res.json({ 
      success: true, 
      callId,
      savedEntries: transcripts.length,
      message: 'Transcript saved successfully (simulated)'
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`🎤 Free Transcription Server running on port ${PORT}`);
  console.log(`✅ No native dependencies required`);
  console.log(`🚀 Ready for Flutter clients`);
});