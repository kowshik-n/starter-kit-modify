import { supabase} from '@/utils/supabase'
import { NextResponse } from 'next/server'
import { transcribeAudio } from '@/lib/aws/transcribe'

export async function POST(req: Request) {
  try {
    // const supabase = createServerClient()
    
    // Check authentication
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      )
    }

    // Get the form data with the audio file
    const formData = await req.formData()
    const audioFile = formData.get('audio') as File
    const title = formData.get('title') as string || 'Untitled'

    if (!audioFile) {
      return NextResponse.json(
        { error: 'No audio file provided' },
        { status: 400 }
      )
    }

    // Upload to temporary storage in Supabase
    const fileName = `${user.id}/${Date.now()}_${audioFile.name}`
    const { data: uploadData, error: uploadError } = await supabase.storage
      .from('temp_audio')
      .upload(fileName, audioFile, {
        cacheControl: '3600',
        upsert: false
      })

    if (uploadError) {
      console.error('Upload error:', uploadError)
      return NextResponse.json(
        { error: 'Failed to upload audio file' },
        { status: 500 }
      )
    }

    // Get the public URL for the uploaded file
    const { data: { publicUrl } } = supabase.storage
      .from('temp_audio')
      .getPublicUrl(fileName)

    // Start transcription job
    const transcriptionResult = await transcribeAudio(publicUrl)

    // Delete the audio file after transcription
    await supabase.storage
      .from('temp_audio')
      .remove([fileName])

    // Return the transcription result
    return NextResponse.json({ 
      transcription: transcriptionResult,
      title
    })
  } catch (error) {
    console.error('Transcription error:', error)
    return NextResponse.json(
      { error: 'Error processing transcription' },
      { status: 500 }
    )
  }
} 