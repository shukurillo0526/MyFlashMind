-- MyFlashMind Supabase Database Schema
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor > New Query)

-- Enable Row Level Security
-- Users can only access their own data

-- 1. Create flashcard_sets table
CREATE TABLE IF NOT EXISTS flashcard_sets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  term_language TEXT,
  definition_language TEXT,
  folder_id UUID,
  cards_known INTEGER DEFAULT 0,
  cards_learning INTEGER DEFAULT 0,
  last_studied TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Create flashcards table
CREATE TABLE IF NOT EXISTS flashcards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  set_id UUID REFERENCES flashcard_sets(id) ON DELETE CASCADE NOT NULL,
  term TEXT NOT NULL,
  definition TEXT NOT NULL,
  term_language TEXT,
  definition_language TEXT,
  image_url TEXT,
  times_correct INTEGER DEFAULT 0,
  times_incorrect INTEGER DEFAULT 0,
  last_studied TIMESTAMPTZ,
  is_starred BOOLEAN DEFAULT FALSE,
  position INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Create folders table
CREATE TABLE IF NOT EXISTS folders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Enable Row Level Security
ALTER TABLE flashcard_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE flashcards ENABLE ROW LEVEL SECURITY;
ALTER TABLE folders ENABLE ROW LEVEL SECURITY;

-- 5. Create RLS Policies

-- Flashcard sets: users can only access their own sets
CREATE POLICY "Users can view own sets" ON flashcard_sets
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sets" ON flashcard_sets
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sets" ON flashcard_sets
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own sets" ON flashcard_sets
  FOR DELETE USING (auth.uid() = user_id);

-- Flashcards: users can access cards in their own sets
CREATE POLICY "Users can view own cards" ON flashcards
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM flashcard_sets WHERE flashcard_sets.id = flashcards.set_id AND flashcard_sets.user_id = auth.uid())
  );

CREATE POLICY "Users can insert own cards" ON flashcards
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM flashcard_sets WHERE flashcard_sets.id = flashcards.set_id AND flashcard_sets.user_id = auth.uid())
  );

CREATE POLICY "Users can update own cards" ON flashcards
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM flashcard_sets WHERE flashcard_sets.id = flashcards.set_id AND flashcard_sets.user_id = auth.uid())
  );

CREATE POLICY "Users can delete own cards" ON flashcards
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM flashcard_sets WHERE flashcard_sets.id = flashcards.set_id AND flashcard_sets.user_id = auth.uid())
  );

-- Folders: users can only access their own folders
CREATE POLICY "Users can view own folders" ON folders
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own folders" ON folders
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own folders" ON folders
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own folders" ON folders
  FOR DELETE USING (auth.uid() = user_id);

-- 6. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_flashcard_sets_user_id ON flashcard_sets(user_id);
CREATE INDEX IF NOT EXISTS idx_flashcards_set_id ON flashcards(set_id);
CREATE INDEX IF NOT EXISTS idx_folders_user_id ON folders(user_id);

-- Done! Now enable Email auth in Supabase Dashboard:
-- Authentication > Providers > Email > Enable
