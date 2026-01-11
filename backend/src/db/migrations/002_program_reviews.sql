-- SkillTrack Pro - Program reviews (program-level feedback)

CREATE TABLE IF NOT EXISTS program_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id uuid NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
  learner_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating int NOT NULL CHECK (rating >= 1 AND rating <= 5),
  feedback text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (program_id, learner_id)
);

CREATE INDEX IF NOT EXISTS idx_program_reviews_program_id ON program_reviews(program_id);
CREATE INDEX IF NOT EXISTS idx_program_reviews_learner_id ON program_reviews(learner_id);
