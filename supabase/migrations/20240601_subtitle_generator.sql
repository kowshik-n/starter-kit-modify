-- Create subtitles table to store the transliterated content
CREATE TABLE public.subtitles (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title text NOT NULL DEFAULT 'Untitled',
  content jsonb NOT NULL, -- Will store the subtitle segments with timestamps and text
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create a storage bucket for temporary audio files
-- These will be deleted after processing
INSERT INTO storage.buckets (id, name, public) 
VALUES ('temp_audio', 'temp_audio', false)
ON CONFLICT DO NOTHING;

-- Enable Row Level Security
ALTER TABLE public.subtitles ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for subtitles
CREATE POLICY "Users can view their own subtitles"
  ON public.subtitles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own subtitles"
  ON public.subtitles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own subtitles"
  ON public.subtitles FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own subtitles"
  ON public.subtitles FOR DELETE
  USING (auth.uid() = user_id);

-- Create storage policies for temp_audio bucket
CREATE POLICY "Users can upload their own audio files"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'temp_audio' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can access their own audio files"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'temp_audio' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can delete their own audio files"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'temp_audio' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Create a function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_subtitle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger for the updated_at column
CREATE TRIGGER update_subtitles_updated_at
  BEFORE UPDATE ON public.subtitles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_subtitle_updated_at(); 