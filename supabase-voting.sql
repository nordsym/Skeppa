-- =============================================
-- SKEPPA.NU - RÖSTNING + MONTHLY SCORES
-- Kör i: https://supabase.com/dashboard/project/qjouribmhkkhqdsieprs/sql
-- =============================================

-- =============================================
-- 1. VOTES TABELL
-- =============================================
CREATE TABLE IF NOT EXISTS votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    voter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    submission_id UUID NOT NULL REFERENCES submissions(id) ON DELETE CASCADE,
    month TEXT NOT NULL, -- "2026-02"
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- 1 röst per user per månad
    UNIQUE(voter_id, month)
);

-- Index för snabba lookups
CREATE INDEX IF NOT EXISTS idx_votes_voter ON votes(voter_id);
CREATE INDEX IF NOT EXISTS idx_votes_submission ON votes(submission_id);
CREATE INDEX IF NOT EXISTS idx_votes_month ON votes(month);

-- RLS
ALTER TABLE votes ENABLE ROW LEVEL SECURITY;

-- Alla kan läsa röster (för att kolla om man redan röstat)
CREATE POLICY "Anyone can read votes" ON votes FOR SELECT USING (true);

-- Users kan bara skapa egna röster
CREATE POLICY "Users can create own votes" ON votes FOR INSERT
WITH CHECK (auth.uid() = voter_id);

-- =============================================
-- 2. MONTHLY_SCORES TABELL
-- =============================================
CREATE TABLE IF NOT EXISTS monthly_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    month TEXT NOT NULL, -- "2026-02"
    points INTEGER DEFAULT 0,
    submissions_count INTEGER DEFAULT 0,
    votes_received INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id, month)
);

-- Index
CREATE INDEX IF NOT EXISTS idx_monthly_scores_month ON monthly_scores(month);
CREATE INDEX IF NOT EXISTS idx_monthly_scores_points ON monthly_scores(points DESC);

-- RLS
ALTER TABLE monthly_scores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read monthly_scores" ON monthly_scores FOR SELECT USING (true);

-- =============================================
-- 3. UPPDATERA PROFILES MED TOTAL_XP
-- =============================================
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS total_xp INTEGER DEFAULT 0;

-- Synka befintliga total_points till total_xp
UPDATE profiles SET total_xp = total_points WHERE total_xp = 0 AND total_points > 0;

-- =============================================
-- 4. TRIGGER: SUBMISSION → MONTHLY_SCORES + TOTAL_XP
-- =============================================
CREATE OR REPLACE FUNCTION handle_new_submission()
RETURNS TRIGGER AS $$
DECLARE
    current_month TEXT;
    points_earned INTEGER := 10;
BEGIN
    current_month := TO_CHAR(NOW(), 'YYYY-MM');

    -- Uppdatera eller skapa monthly_scores
    INSERT INTO monthly_scores (user_id, month, points, submissions_count)
    VALUES (NEW.user_id, current_month, points_earned, 1)
    ON CONFLICT (user_id, month) DO UPDATE SET
        points = monthly_scores.points + points_earned,
        submissions_count = monthly_scores.submissions_count + 1,
        updated_at = NOW();

    -- Uppdatera total_xp och total_points på profiles
    UPDATE profiles SET
        total_xp = COALESCE(total_xp, 0) + points_earned,
        total_points = COALESCE(total_points, 0) + points_earned
    WHERE id = NEW.user_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Skapa trigger (ersätt gammal om den finns)
DROP TRIGGER IF EXISTS trigger_new_submission ON submissions;
CREATE TRIGGER trigger_new_submission
AFTER INSERT ON submissions
FOR EACH ROW EXECUTE FUNCTION handle_new_submission();

-- =============================================
-- 5. TRIGGER: RÖST → POÄNG TILL PROJEKTSKAPARE
-- =============================================
CREATE OR REPLACE FUNCTION handle_new_vote()
RETURNS TRIGGER AS $$
DECLARE
    submission_owner UUID;
    current_month TEXT;
    vote_points INTEGER := 50;
BEGIN
    current_month := TO_CHAR(NOW(), 'YYYY-MM');

    -- Hämta submission owner
    SELECT user_id INTO submission_owner FROM submissions WHERE id = NEW.submission_id;

    -- Kan inte rösta på sig själv (extra säkerhet)
    IF submission_owner = NEW.voter_id THEN
        RAISE EXCEPTION 'Cannot vote on own submission';
    END IF;

    -- Ge poäng till projektskaparen
    INSERT INTO monthly_scores (user_id, month, points, votes_received)
    VALUES (submission_owner, current_month, vote_points, 1)
    ON CONFLICT (user_id, month) DO UPDATE SET
        points = monthly_scores.points + vote_points,
        votes_received = monthly_scores.votes_received + 1,
        updated_at = NOW();

    -- Uppdatera total_xp på profiles
    UPDATE profiles SET
        total_xp = COALESCE(total_xp, 0) + vote_points,
        total_points = COALESCE(total_points, 0) + vote_points
    WHERE id = submission_owner;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_new_vote ON votes;
CREATE TRIGGER trigger_new_vote
AFTER INSERT ON votes
FOR EACH ROW EXECUTE FUNCTION handle_new_vote();

-- =============================================
-- 6. FUNKTION: KOLLA OM USER KAN RÖSTA
-- =============================================
CREATE OR REPLACE FUNCTION can_vote(p_voter_id UUID, p_submission_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    submission_owner UUID;
    current_month TEXT;
    already_voted BOOLEAN;
BEGIN
    current_month := TO_CHAR(NOW(), 'YYYY-MM');

    -- Kolla om det är eget projekt
    SELECT user_id INTO submission_owner FROM submissions WHERE id = p_submission_id;
    IF submission_owner = p_voter_id THEN
        RETURN FALSE;
    END IF;

    -- Kolla om redan röstat denna månad
    SELECT EXISTS(
        SELECT 1 FROM votes WHERE voter_id = p_voter_id AND month = current_month
    ) INTO already_voted;

    RETURN NOT already_voted;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 7. MIGRERA BEFINTLIGA SUBMISSIONS TILL MONTHLY_SCORES
-- =============================================
INSERT INTO monthly_scores (user_id, month, points, submissions_count)
SELECT
    user_id,
    TO_CHAR(created_at, 'YYYY-MM') as month,
    SUM(points_earned) as points,
    COUNT(*) as submissions_count
FROM submissions
GROUP BY user_id, TO_CHAR(created_at, 'YYYY-MM')
ON CONFLICT (user_id, month) DO UPDATE SET
    points = EXCLUDED.points,
    submissions_count = EXCLUDED.submissions_count;

-- =============================================
-- 8. MÅNADENS KAPTEN BADGE (id behövs)
-- =============================================
INSERT INTO badges (slug, name, description, icon)
VALUES ('manadenskapten', 'Månadens Kapten', 'Vinnare av månadens topplista', 'crown')
ON CONFLICT (slug) DO NOTHING;

-- =============================================
-- DONE! Verifiera med:
-- SELECT * FROM votes;
-- SELECT * FROM monthly_scores ORDER BY month DESC, points DESC;
-- SELECT id, username, total_xp, total_points FROM profiles;
-- =============================================
