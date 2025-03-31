interface SubtitleSegment {
  index: number;
  startTime: number;
  endTime: number;
  text: string;
  transliterated: string;
}

export function convertToSRT(subtitles: SubtitleSegment[]): string {
  return subtitles.map(segment => {
    // Format: sequence number
    const sequenceNumber = segment.index;
    
    // Format: start time --> end time
    const startTime = formatTime(segment.startTime);
    const endTime = formatTime(segment.endTime);
    const timeCode = `${startTime} --> ${endTime}`;
    
    // Format: subtitle text (use transliterated text)
    const text = segment.transliterated;
    
    // Combine all parts with proper line breaks
    return `${sequenceNumber}\n${timeCode}\n${text}\n`;
  }).join('\n');
}

// Helper function to format time in SRT format (00:00:00,000)
function formatTime(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);
  const milliseconds = Math.floor((seconds % 1) * 1000);
  
  return `${padZero(hours)}:${padZero(minutes)}:${padZero(secs)},${padZero(milliseconds, 3)}`;
}

// Helper function to pad numbers with leading zeros
function padZero(num: number, length: number = 2): string {
  return num.toString().padStart(length, '0');
} 