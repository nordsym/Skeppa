# Skeppa.nu - Claude Code Context

## Projekt
Single-file MVP för månatlig "ship your project"-challenge.

**Fil:** `/Users/gustavhemmingsson/Projects/Skeppa/index.html`

---

## Supabase

**URL:** `https://qjouribmhkkhqdsieprs.supabase.co`

**Anon Key:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFqb3VyaWJtaGtraHFkc2llcHJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg0OTE3OTcsImV4cCI6MjA4NDA2Nzc5N30.GK2bZyl1Ja5T3AHnj7jQnt3UI7B-v70N7onfoxYPm2E`

**Dashboard:** https://supabase.com/dashboard/project/qjouribmhkkhqdsieprs

### Tabeller
- `profiles` - User profiles (username, display_name, avatar_url, points)
- `submissions` - Project submissions
- `batches` - Monthly batches/themes
- `badges` / `user_badges` - Achievement system
- `waitlist` - Email waitlist

### Views
- `leaderboard` - Aggregated user stats
- `recent_submissions` - Latest submissions with user info

---

## Lärdomar från Debug Session (2026-01-29)

### Problem: JS kördes inte alls
**Orsak:** `let supabase` krockade med `window.supabase` (SDK:t)

**Fix:** Byt variabelnamn till `db`:
```javascript
// FEL - krockar med SDK
let supabase = window.supabase.createClient(URL, KEY);

// RÄTT
let db = window.supabase.createClient(URL, KEY);
```

### Problem: 401 Unauthorized
**Orsak:** Gammal/trunkerad API-nyckel

**Fix:** Hämta korrekt anon key från Dashboard > Settings > API

### Best Practice: Graceful degradation
```javascript
async function testSupabaseConnection() {
    if (!db) return false;
    try {
        const { error } = await db.from('profiles').select('id').limit(1);
        if (error && error.message.includes('Invalid API key')) {
            console.error('Invalid API key');
            return false;
        }
        return true;
    } catch (e) {
        return false;
    }
}
```

---

## CLI Script

```bash
~/bin/supabase-api GET profiles 'select=*&limit=10'
~/bin/supabase-api GET leaderboard 'select=*&order=total_points.desc'
~/bin/supabase-api GET submissions 'select=*,profiles(username)'
```

---

## Design

- Dark-first med light mode toggle
- CSS Variables för theming
- Tailwind 2.x via CDN
- Phosphor Icons
- Fonts: DM Serif Display (headings), Inter (body)
