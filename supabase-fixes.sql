-- =============================================
-- SKEPPA.NU - POÄNG-FIX + BADGES + LEVEL SYSTEM
-- Kör i Supabase SQL Editor: https://supabase.com/dashboard/project/qjouribmhkkhqdsieprs/sql
-- =============================================

-- =============================================
-- 1. FIXA PROFILES - Lägg till level-kolumner
-- =============================================
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS level INTEGER DEFAULT 1;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS current_xp INTEGER DEFAULT 0;

-- =============================================
-- 2. FÖRBÄTTRAD TRIGGER: Uppdatera points + level + badges
-- =============================================

-- Level thresholds (XP needed for each level)
-- Level 1: 0-49p, Level 2: 50-149p, Level 3: 150-299p, Level 4: 300-499p, Level 5: 500+p
CREATE OR REPLACE FUNCTION calculate_level(points INTEGER)
RETURNS INTEGER AS $$
BEGIN
    IF points >= 500 THEN RETURN 5;
    ELSIF points >= 300 THEN RETURN 4;
    ELSIF points >= 150 THEN RETURN 3;
    ELSIF points >= 50 THEN RETURN 2;
    ELSE RETURN 1;
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- XP progress within current level
CREATE OR REPLACE FUNCTION calculate_xp_in_level(points INTEGER)
RETURNS INTEGER AS $$
DECLARE
    level_start INTEGER;
BEGIN
    IF points >= 500 THEN level_start := 500;
    ELSIF points >= 300 THEN level_start := 300;
    ELSIF points >= 150 THEN level_start := 150;
    ELSIF points >= 50 THEN level_start := 50;
    ELSE level_start := 0;
    END IF;
    RETURN points - level_start;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Main trigger function
CREATE OR REPLACE FUNCTION update_user_points_and_badges()
RETURNS TRIGGER AS $$
DECLARE
    new_total INTEGER;
    submission_count INTEGER;
    monthly_count INTEGER;
    has_ai_tag BOOLEAN;
    has_repo BOOLEAN;
    badge_record RECORD;
BEGIN
    -- Calculate new total points
    SELECT COALESCE(SUM(points_earned), 0) INTO new_total
    FROM submissions
    WHERE user_id = NEW.user_id;

    -- Update profile with points and calculated level
    UPDATE profiles
    SET
        total_points = new_total,
        level = calculate_level(new_total),
        current_xp = calculate_xp_in_level(new_total)
    WHERE id = NEW.user_id;

    -- Count submissions for badge logic
    SELECT COUNT(*) INTO submission_count
    FROM submissions
    WHERE user_id = NEW.user_id;

    -- Count submissions this month
    SELECT COUNT(*) INTO monthly_count
    FROM submissions
    WHERE user_id = NEW.user_id
    AND DATE_TRUNC('month', created_at) = DATE_TRUNC('month', NOW());

    -- Check for AI tag
    has_ai_tag := 'AI' = ANY(NEW.tags);

    -- Check for repo
    has_repo := NEW.repo_url IS NOT NULL AND NEW.repo_url != '';

    -- ===== BADGE: Jungfrufärd (first submission) =====
    IF submission_count = 1 THEN
        INSERT INTO user_badges (user_id, badge_id)
        SELECT NEW.user_id, id FROM badges WHERE slug = 'jungfrufard'
        ON CONFLICT DO NOTHING;
    END IF;

    -- ===== BADGE: Dubbellast (2 submissions same month) =====
    IF monthly_count >= 2 THEN
        INSERT INTO user_badges (user_id, badge_id)
        SELECT NEW.user_id, id FROM badges WHERE slug = 'dubbellast'
        ON CONFLICT DO NOTHING;
    END IF;

    -- ===== BADGE: Hattrick (3 submissions same month) =====
    IF monthly_count >= 3 THEN
        INSERT INTO user_badges (user_id, badge_id)
        SELECT NEW.user_id, id FROM badges WHERE slug = 'hattrick'
        ON CONFLICT DO NOTHING;
    END IF;

    -- ===== BADGE: Kapten (5 submissions same month) =====
    IF monthly_count >= 5 THEN
        INSERT INTO user_badges (user_id, badge_id)
        SELECT NEW.user_id, id FROM badges WHERE slug = 'kapten'
        ON CONFLICT DO NOTHING;
    END IF;

    -- ===== BADGE: AI-Arkitekt (AI tag) =====
    IF has_ai_tag THEN
        INSERT INTO user_badges (user_id, badge_id)
        SELECT NEW.user_id, id FROM badges WHERE slug = 'ai-arkitekt'
        ON CONFLICT DO NOTHING;
    END IF;

    -- ===== BADGE: Open Source Hero (has repo) =====
    IF has_repo THEN
        INSERT INTO user_badges (user_id, badge_id)
        SELECT NEW.user_id, id FROM badges WHERE slug = 'open-source'
        ON CONFLICT DO NOTHING;
    END IF;

    -- ===== BADGE: Early Bird (first 7 days of month) =====
    IF EXTRACT(DAY FROM NEW.created_at) <= 7 THEN
        INSERT INTO user_badges (user_id, badge_id)
        SELECT NEW.user_id, id FROM badges WHERE slug = 'early-bird'
        ON CONFLICT DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop old trigger and create new one
DROP TRIGGER IF EXISTS trigger_update_user_points ON submissions;
CREATE TRIGGER trigger_update_user_points
AFTER INSERT ON submissions
FOR EACH ROW
EXECUTE FUNCTION update_user_points_and_badges();

-- =============================================
-- 3. USER_BADGES - Säkerställ unik constraint
-- =============================================
ALTER TABLE user_badges
ADD CONSTRAINT IF NOT EXISTS unique_user_badge
UNIQUE (user_id, badge_id);

-- Om constraint redan finns, ignorera error
DO $$
BEGIN
    ALTER TABLE user_badges ADD CONSTRAINT unique_user_badge UNIQUE (user_id, badge_id);
EXCEPTION
    WHEN duplicate_table THEN NULL;
    WHEN duplicate_object THEN NULL;
END $$;

-- =============================================
-- 4. REKALKULERA ALLA POÄNG OCH BADGES
-- =============================================

-- Rekalkulera total_points för alla users
UPDATE profiles p
SET
    total_points = COALESCE((
        SELECT SUM(points_earned)
        FROM submissions s
        WHERE s.user_id = p.id
    ), 0);

-- Uppdatera level baserat på poäng
UPDATE profiles
SET
    level = calculate_level(total_points),
    current_xp = calculate_xp_in_level(total_points);

-- =============================================
-- 5. TILLDELA BADGES RETROAKTIVT
-- =============================================

-- Jungfrufärd för alla som har minst 1 submission
INSERT INTO user_badges (user_id, badge_id)
SELECT DISTINCT s.user_id, b.id
FROM submissions s
CROSS JOIN badges b
WHERE b.slug = 'jungfrufard'
AND NOT EXISTS (
    SELECT 1 FROM user_badges ub
    WHERE ub.user_id = s.user_id AND ub.badge_id = b.id
);

-- AI-Arkitekt för alla som har AI-taggade submissions
INSERT INTO user_badges (user_id, badge_id)
SELECT DISTINCT s.user_id, b.id
FROM submissions s
CROSS JOIN badges b
WHERE b.slug = 'ai-arkitekt'
AND 'AI' = ANY(s.tags)
AND NOT EXISTS (
    SELECT 1 FROM user_badges ub
    WHERE ub.user_id = s.user_id AND ub.badge_id = b.id
);

-- Open Source Hero för alla med repo_url
INSERT INTO user_badges (user_id, badge_id)
SELECT DISTINCT s.user_id, b.id
FROM submissions s
CROSS JOIN badges b
WHERE b.slug = 'open-source'
AND s.repo_url IS NOT NULL AND s.repo_url != ''
AND NOT EXISTS (
    SELECT 1 FROM user_badges ub
    WHERE ub.user_id = s.user_id AND ub.badge_id = b.id
);

-- Dubbellast, Hattrick, Kapten baserat på monthly counts
WITH monthly_counts AS (
    SELECT
        user_id,
        DATE_TRUNC('month', created_at) as month,
        COUNT(*) as count
    FROM submissions
    GROUP BY user_id, DATE_TRUNC('month', created_at)
)
INSERT INTO user_badges (user_id, badge_id)
SELECT DISTINCT mc.user_id, b.id
FROM monthly_counts mc
CROSS JOIN badges b
WHERE
    (b.slug = 'dubbellast' AND mc.count >= 2) OR
    (b.slug = 'hattrick' AND mc.count >= 3) OR
    (b.slug = 'kapten' AND mc.count >= 5)
AND NOT EXISTS (
    SELECT 1 FROM user_badges ub
    WHERE ub.user_id = mc.user_id AND ub.badge_id = b.id
);

-- Early Bird för submissions första 7 dagarna
INSERT INTO user_badges (user_id, badge_id)
SELECT DISTINCT s.user_id, b.id
FROM submissions s
CROSS JOIN badges b
WHERE b.slug = 'early-bird'
AND EXTRACT(DAY FROM s.created_at) <= 7
AND NOT EXISTS (
    SELECT 1 FROM user_badges ub
    WHERE ub.user_id = s.user_id AND ub.badge_id = b.id
);

-- =============================================
-- 6. UPPDATERAD LEADERBOARD VIEW MED BADGE-INFO
-- =============================================
DROP VIEW IF EXISTS leaderboard;
CREATE VIEW leaderboard AS
SELECT
    p.id,
    p.username,
    p.display_name,
    p.avatar_url,
    p.total_points,
    p.level,
    COUNT(DISTINCT s.id) as submission_count,
    COALESCE(
        (SELECT json_agg(json_build_object(
            'slug', b.slug,
            'name', b.name,
            'icon', b.icon
        ))
        FROM user_badges ub
        JOIN badges b ON ub.badge_id = b.id
        WHERE ub.user_id = p.id),
        '[]'::json
    ) as badges
FROM profiles p
LEFT JOIN submissions s ON p.id = s.user_id
WHERE p.total_points > 0
GROUP BY p.id, p.username, p.display_name, p.avatar_url, p.total_points, p.level
ORDER BY p.total_points DESC;

-- =============================================
-- 7. USER PROFILE VIEW (för Mina Sidor)
-- =============================================
CREATE OR REPLACE VIEW user_profile_details AS
SELECT
    p.id,
    p.username,
    p.display_name,
    p.avatar_url,
    p.total_points,
    p.level,
    p.current_xp,
    -- XP needed for next level
    CASE
        WHEN p.level = 1 THEN 50
        WHEN p.level = 2 THEN 100  -- 150-50
        WHEN p.level = 3 THEN 150  -- 300-150
        WHEN p.level = 4 THEN 200  -- 500-300
        ELSE 0  -- Max level
    END as xp_for_next_level,
    COUNT(DISTINCT s.id) as submission_count,
    COALESCE(
        (SELECT json_agg(json_build_object(
            'slug', b.slug,
            'name', b.name,
            'icon', b.icon,
            'description', b.description,
            'earned_at', ub.created_at
        ) ORDER BY ub.created_at)
        FROM user_badges ub
        JOIN badges b ON ub.badge_id = b.id
        WHERE ub.user_id = p.id),
        '[]'::json
    ) as badges
FROM profiles p
LEFT JOIN submissions s ON p.id = s.user_id
GROUP BY p.id, p.username, p.display_name, p.avatar_url, p.total_points, p.level, p.current_xp;

-- =============================================
-- 8. RLS POLICIES
-- =============================================

-- User badges readable by all
ALTER TABLE user_badges ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read user_badges" ON user_badges;
CREATE POLICY "Anyone can read user_badges" ON user_badges FOR SELECT USING (true);

-- System can insert badges (via trigger)
DROP POLICY IF EXISTS "System can insert badges" ON user_badges;
CREATE POLICY "System can insert badges" ON user_badges FOR INSERT WITH CHECK (true);

-- =============================================
-- DONE! Verifiera med:
-- SELECT * FROM profiles;
-- SELECT * FROM user_badges;
-- SELECT * FROM leaderboard;
-- =============================================
