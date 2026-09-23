# SunKidz Web

Marketing website for [SunKidz](https://sunkidz.in) — preschool, daycare, and summer camps in Bangalore.

Frontend only (Vite + React + TypeScript). Enquiry form opens the visitor’s email client; no backend yet.

## Quick start

```bash
cd sunkidz-web
npm install
npm run dev
```

Open the URL Vite prints (usually `http://localhost:5173`).

## Scripts

| Command           | Description              |
| ----------------- | ------------------------ |
| `npm run dev`     | Local development server |
| `npm run build`   | Production build → `dist/` |
| `npm run preview` | Preview the production build |

## Pages

- `/` — Home (brand hero, pillars, programs, branches)
- `/about` — Story, mission, vision, Foundations for Success
- `/programs` — Preschool, daycare, summer camps
- `/approach` — Four curriculum pillars + T.E.L.M examples
- `/branches` — Munnekolala, Ashwath Nagar, AECS Layout
- `/enquire` — Parent enquiry form (mailto)

## Stack

- React 19 + React Router
- CSS design tokens (`src/styles/tokens.css`)
- Static content in `src/data/content.ts`
