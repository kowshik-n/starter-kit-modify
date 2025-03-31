import { supabase} from '@/utils/supabase'
import { NextResponse } from 'next/server'
import { transliterateTamilText } from '@/lib/openai/transliterate'

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

    const { transcription, title } = await req.json()

    if (!transcription) {
      return NextResponse.json(
        { error: 'No transcription provided' },
        { status: 400 }
      )
    }

    // Transliterate the Tamil text to English characters
    const transliteratedSubtitles = await transliterateTamilText(transcription)

    // Store the transliterated subtitles in the database
    const { data: subtitle, error: insertError } = await supabase
      .from('subtitles')
      .insert({
        user_id: user.id,
        title: title || 'Untitled',
        content: transliteratedSubtitles
      })
      .select()
      .single()

    if (insertError) {
      console.error('Insert error:', insertError)
      return NextResponse.json(
        { error: 'Failed to save subtitles' },
        { status: 500 }
      )
    }

    return NextResponse.json({ 
      id: subtitle.id,
      subtitles: transliteratedSubtitles
    })
  } catch (error) {
    console.error('Transliteration error:', error)
    return NextResponse.json(
      { error: 'Error processing transliteration' },
      { status: 500 }
    )
  }
} 