import { supabase} from '@/utils/supabase'
import { NextResponse } from 'next/server'
import { convertToSRT } from '@/lib/subtitles/converter'

export async function GET(
  req: Request,
  { params }: { params: { id: string } }
) {
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

    // Get the subtitle by ID
    const { data: subtitle, error } = await supabase
      .from('subtitles')
      .select('*')
      .eq('id', params.id)
      .eq('user_id', user.id)
      .single()

    if (error) {
      console.error('Database error:', error)
      return NextResponse.json(
        { error: 'Failed to fetch subtitle' },
        { status: 500 }
      )
    }

    // Convert the subtitle content to SRT format
    const srtContent = convertToSRT(subtitle.content)
    
    // Create a response with the SRT content as a downloadable file
    const response = new NextResponse(srtContent)
    response.headers.set('Content-Type', 'text/plain')
    response.headers.set('Content-Disposition', `attachment; filename="${subtitle.title.replace(/[^a-z0-9]/gi, '_').toLowerCase()}.srt"`)
    
    return response
  } catch (error) {
    console.error('Error:', error)
    return NextResponse.json(
      { error: 'Error exporting subtitle' },
      { status: 500 }
    )
  }
} 