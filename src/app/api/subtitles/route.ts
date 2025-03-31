import { supabase} from '@/utils/supabase'
import { NextResponse } from 'next/server'

export async function GET(req: Request) {
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

    // Get all subtitles for the user
    const { data: subtitles, error } = await supabase
      .from('subtitles')
      .select('id, title, created_at, updated_at')
      .eq('user_id', user.id)
      .order('updated_at', { ascending: false })

    if (error) {
      console.error('Database error:', error)
      return NextResponse.json(
        { error: 'Failed to fetch subtitles' },
        { status: 500 }
      )
    }

    return NextResponse.json({ subtitles })
  } catch (error) {
    console.error('Error:', error)
    return NextResponse.json(
      { error: 'Error fetching subtitles' },
      { status: 500 }
    )
  }
} 