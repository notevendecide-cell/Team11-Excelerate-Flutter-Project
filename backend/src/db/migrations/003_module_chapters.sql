-- SkillTrack Pro - Module chapters (Markdown)

CREATE TABLE IF NOT EXISTS module_chapters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_id uuid NOT NULL REFERENCES milestones(id) ON DELETE CASCADE,
  title text NOT NULL,
  sort_order int NOT NULL DEFAULT 0,
  body_md text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_module_chapters_milestone_id ON module_chapters(milestone_id);
CREATE INDEX IF NOT EXISTS idx_module_chapters_order ON module_chapters(milestone_id, sort_order, created_at);
