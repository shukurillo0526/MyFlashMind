-- ============================================
-- MyFlashMind Database Migration
-- Run this in Supabase Dashboard > SQL Editor
-- ============================================

-- Migration: Add SM-2 spaced repetition columns to flashcards table
ALTER TABLE flashcards 
  ADD COLUMN IF NOT EXISTS easiness_factor DOUBLE PRECISION DEFAULT 2.5,
  ADD COLUMN IF NOT EXISTS interval INTEGER DEFAULT 1,
  ADD COLUMN IF NOT EXISTS repetitions INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS next_review_date TIMESTAMPTZ;

-- Migration: Add set_ids array to folders table  
ALTER TABLE folders
  ADD COLUMN IF NOT EXISTS set_ids TEXT[] DEFAULT '{}';

-- Verify the columns were added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'flashcards' 
  AND column_name IN ('easiness_factor', 'interval', 'repetitions', 'next_review_date');
