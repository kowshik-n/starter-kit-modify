import AWS from 'aws-sdk'

// Configure AWS
AWS.config.update({
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  region: process.env.AWS_REGION || 'us-east-1'
})

const transcribe = new AWS.TranscribeService()

export async function transcribeAudio(audioUrl: string): Promise<string> {
  const jobName = `tamil-transcription-${Date.now()}`
  
  // Start transcription job
  await transcribe.startTranscriptionJob({
    TranscriptionJobName: jobName,
    Media: { MediaFileUri: audioUrl },
    LanguageCode: 'ta-IN', // Tamil language code
    MediaFormat: 'mp3', // Adjust based on your audio format
    OutputBucketName: process.env.AWS_S3_BUCKET_NAME,
  }).promise()
  
  // Poll for job completion
  let completed = false
  let transcriptionResult = ''
  
  while (!completed) {
    await new Promise(resolve => setTimeout(resolve, 5000)) // Wait 5 seconds between checks
    
    const { TranscriptionJob } = await transcribe.getTranscriptionJob({
      TranscriptionJobName: jobName
    }).promise()
    
    if (TranscriptionJob?.TranscriptionJobStatus === 'COMPLETED') {
      completed = true
      
      // Get the transcript file from S3
      if (TranscriptionJob.Transcript?.TranscriptFileUri) {
        const response = await fetch(TranscriptionJob.Transcript.TranscriptFileUri)
        const data = await response.json()
        transcriptionResult = data.results.transcripts[0].transcript
      }
    } else if (
      TranscriptionJob?.TranscriptionJobStatus === 'FAILED' || 
      TranscriptionJob?.TranscriptionJobStatus === 'CANCELED'
    ) {
      throw new Error(`Transcription job ${jobName} failed or was canceled`)
    }
  }
  
  return transcriptionResult
} 