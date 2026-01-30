# ⛵ Skeppa.nu

> **Börja skeppa kod med andra utvecklare**

[![Live Site](https://img.shields.io/badge/🌐_Live-skeppa.nu-00D4FF?style=for-the-badge)](https://skeppa.nu)
[![GitHub Pages](https://img.shields.io/badge/Hosted_on-GitHub_Pages-222?style=for-the-badge&logo=github)](https://pages.github.com/)
[![Supabase](https://img.shields.io/badge/Backend-Supabase-3ECF8E?style=for-the-badge&logo=supabase)](https://supabase.com)

---

## 🎯 Vad är Skeppa?

**Skeppa.nu** är en community-driven plattform för **månatliga kodutmaningar** med fokus på AI och snabb utveckling.

Konceptet är enkelt: **Bygg något. Skeppa det. Gör det igen.**

Varje månad släpps ett nytt tema, och deltagare har en månad på sig att bygga och dela sina projekt. Poäng delas ut för deltagande, och de bästa projekten lyfts fram på leaderboarden.

### 🏆 Poängsystem

| Handling | Poäng |
|----------|-------|
| Skicka in ett projekt | +100 |
| Första inlämningen | +50 bonus |
| Streak (flera månader i rad) | +25/månad |
| Community-röster | +10/röst |

---

## ✨ Features

- 🎨 **Dark/Light mode** med smooth transitions
- 📊 **Live leaderboard** med realtidsuppdateringar
- 🏅 **Badge-system** för achievements
- 📬 **Waitlist** för nya användare
- 🗳️ **Roadmap voting** - rösta på kommande features
- 💬 **Feedback-system** för community-input
- 👤 **Användarprofiler** med avatarer och stats
- 📱 **Fully responsive** - fungerar på alla enheter

---

## 🛠️ Tech Stack

| Kategori | Teknologi |
|----------|-----------|
| **Frontend** | Vanilla HTML/CSS/JS (single-file) |
| **Styling** | Tailwind CSS 2.x (CDN) |
| **Icons** | Phosphor Icons |
| **Fonts** | DM Serif Display, Inter, Source Code Pro |
| **Backend** | Supabase (PostgreSQL + Auth + Realtime) |
| **Hosting** | GitHub Pages |
| **Domain** | Cloudflare DNS |

---

## 🚀 Getting Started

### Kör lokalt

```bash
# Klona repot
git clone https://github.com/nordsym/Skeppa.git
cd Skeppa

# Öppna i browser (inget bygge behövs!)
open index.html

# Eller kör en lokal server
python3 -m http.server 8000
# Besök http://localhost:8000
```

### Med live reload

```bash
# Installera live-server globalt
npm install -g live-server

# Starta
live-server
```

---

## 🔐 Environment Variables

Projektet använder Supabase med **anon key** (säker för frontend).

Konfigurera i `index.html`:

```javascript
const SUPABASE_URL = 'https://your-project.supabase.co';
const SUPABASE_KEY = 'your-anon-key';
```

### Supabase Setup

1. Skapa ett projekt på [supabase.com](https://supabase.com)
2. Kör SQL-filerna för schema:
   - `supabase-schema.sql` - Grundtabeller
   - `supabase-voting.sql` - Voting-system
   - `supabase-roadmap-feedback.sql` - Roadmap & feedback
3. Kopiera din **anon key** från Dashboard → Settings → API

---

## 📦 Deploy

### GitHub Pages (rekommenderat)

1. Pusha till `main` branch
2. Gå till repo Settings → Pages
3. Välj "Deploy from branch" → `main`
4. Lägg till custom domain i `CNAME`-filen

```
skeppa.nu
```

### Alternativ: Vercel/Netlify

Fungerar direkt utan konfiguration - bara koppla repot!

---

## 🤝 Contributing

Vi välkomnar bidrag! Så här gör du:

1. **Fork** repot
2. Skapa en **feature branch** (`git checkout -b feature/amazing-feature`)
3. **Commit** dina ändringar (`git commit -m 'Add amazing feature'`)
4. **Push** till branchen (`git push origin feature/amazing-feature`)
5. Öppna en **Pull Request**

### Guidelines

- Håll koden i `index.html` (single-file architecture)
- Följ befintlig kodstil
- Testa i både dark och light mode
- Se till att det fungerar responsivt

---

## 📄 License

MIT License - se [LICENSE](LICENSE) för detaljer.

---

## 🔗 Links

- 🌐 **Live site:** [skeppa.nu](https://skeppa.nu)
- 🐙 **GitHub:** [github.com/nordsym/Skeppa](https://github.com/nordsym/Skeppa)
- 💬 **Discord:** *Coming soon*

---

<div align="center">

**Byggd med ❤️ av [NordSym](https://github.com/nordsym)**

*Sluta planera. Börja skeppa.* ⛵

</div>
