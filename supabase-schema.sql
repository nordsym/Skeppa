-- =============================================
-- SKEPPA.NU SCHEMA UPDATES
-- Kör i Supabase SQL Editor: https://supabase.com/dashboard/project/qjouribmhkkhqdsieprs/sql
-- =============================================

-- 1. PROFILES - Lägg till saknade kolumner
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS username TEXT UNIQUE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS display_name TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS total_points INTEGER DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- Index för snabb username-lookup
CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);

-- 2. SUBMISSIONS - Lägg till saknade kolumner
ALTER TABLE submissions ADD COLUMN IF NOT EXISTS screenshot_url TEXT;
ALTER TABLE submissions ADD COLUMN IF NOT EXISTS demo_url TEXT;
ALTER TABLE submissions ADD COLUMN IF NOT EXISTS video_url TEXT;

-- 3. STORAGE BUCKET för screenshots
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'project-screenshots',
    'project-screenshots',
    true,
    5242880,
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- 4. FUNCTION: Uppdatera user points efter submission
CREATE OR REPLACE FUNCTION update_user_points()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE profiles
    SET total_points = (
        SELECT COALESCE(SUM(points_earned), 0)
        FROM submissions
        WHERE user_id = NEW.user_id
    )
    WHERE id = NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger för automatisk points-uppdatering
DROP TRIGGER IF EXISTS trigger_update_user_points ON submissions;
CREATE TRIGGER trigger_update_user_points
AFTER INSERT OR UPDATE ON submissions
FOR EACH ROW
EXECUTE FUNCTION update_user_points();

-- 5. VIEW: recent_submissions
CREATE OR REPLACE VIEW recent_submissions AS
SELECT
    s.*,
    p.username,
    p.display_name,
    p.avatar_url
FROM submissions s
LEFT JOIN profiles p ON s.user_id = p.id
ORDER BY s.created_at DESC
LIMIT 20;

-- 6. VIEW: leaderboard
CREATE OR REPLACE VIEW leaderboard AS
SELECT
    p.id,
    p.username,
    p.display_name,
    p.avatar_url,
    p.total_points,
    COUNT(s.id) as submission_count,
    ARRAY_AGG(DISTINCT ub.badge_id) FILTER (WHERE ub.badge_id IS NOT NULL) as badges
FROM profiles p
LEFT JOIN submissions s ON p.id = s.user_id
LEFT JOIN user_badges ub ON p.id = ub.user_id
WHERE p.total_points > 0
GROUP BY p.id, p.username, p.display_name, p.avatar_url, p.total_points
ORDER BY p.total_points DESC;
