import OpenAI from 'openai'

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
})

export async function transliterateTamilText(transcription: string): Promise<any[]> {
  // Parse the transcription into segments (this is simplified)
  // In a real implementation, you'd need to parse the AWS transcription result
  // which includes timestamps for each word
  const segments = parseTranscriptionIntoSegments(transcription)
  
  // Process each segment with OpenAI
  const transliteratedSegments = []
  
  for (const segment of segments) {
    const completion = await openai.chat.completions.create({
      model: "gpt-3.5-turbo",
      messages: [
        {
          role: "system",
          content: "You are a Tamil language expert. Transliterate the following Tamil text into English characters. Do not translate the meaning, only convert the Tamil script to English characters that sound the same when pronounced."
        },
        {
          role: "user",
          content: segment.text
        }
      ],
      temperature: 0.3,
    })
    
    transliteratedSegments.push({
      ...segment,
      transliterated: completion.choices[0].message.content
    })
  }
  
  return transliteratedSegments
}

// Helper function to parse transcription into segments with timestamps
function parseTranscriptionIntoSegments(transcription: string) {
  // This is a simplified implementation
  // In a real application, you would use the detailed timing information
  // from AWS Transcribe to create proper segments
  
  // For now, we'll just split by sentences and assign dummy timestamps
  const sentences = transcription.match(/[^.!?]+[.!?]+/g) || [transcription]
  
  return sentences.map((sentence, index) => {
    const startTime = index * 5 // Dummy start time: 5 seconds per segment
    const endTime = startTime + sentence.length / 20 // Rough estimate based on text length
    
    return {
      index: index + 1,
      startTime,
      endTime,
      text: sentence.trim(),
    }
  })
} 