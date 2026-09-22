import { useState } from "react";
import { Link, Navigate, useParams } from "react-router-dom";
import { pillars, type Pillar } from "../data/content";
import "./InnerPages.css";
import "./ApproachDetail.css";

export function ApproachDetail() {
  const { pillarId } = useParams<{ pillarId: string }>();
  const index = pillars.findIndex((p) => p.id === pillarId);
  const pillar = pillars[index];

  if (!pillar) {
    return <Navigate to="/approach" replace />;
  }

  const next = pillars[(index + 1) % pillars.length];

  return (
    <div className="page">
      <div className="container page-hero pillar-hero fade-up">
        <div className="pillar-crumb">
          <Link to="/approach" className="text-link back-link">
            ← All pillars
          </Link>
          <span className={`section-label pillar-eyebrow color-${pillar.color}`}>
            {pillar.code}
          </span>
        </div>
        <span className="pillar-hero-icon" aria-hidden="true">
          {pillar.icon}
        </span>
        <h1>{pillar.title}</h1>
        <p>{pillar.summary}</p>
      </div>

      {/* Keyed by pillar id so the tab selection resets whenever the route changes. */}
      <ActivitySwitcher key={pillar.id} pillar={pillar} />

      <div className="container">
        <Link to={`/approach/${next.id}`} className={`pillar-next color-${next.color}`}>
          <span className="pillar-next-icon" aria-hidden="true">
            {next.icon}
          </span>
          <span className="pillar-next-text">
            <span className="pillar-next-label">Next pillar</span>
            <strong>
              {next.code} — {next.title}
            </strong>
          </span>
          <span className="pillar-next-arrow" aria-hidden="true">
            →
          </span>
        </Link>

        <div className="page-cta">
          <p>Want to see it in person?</p>
          <Link to="/enquire" className="btn btn-primary btn-playful">
            Book a visit
          </Link>
        </div>
      </div>
    </div>
  );
}

function ActivitySwitcher({ pillar }: { pillar: Pillar }) {
  const [active, setActive] = useState(0);
  const examples = pillar.examples ?? [];
  const current = examples[active];

  if (!current) return null;

  return (
    <section className="container pillar-switcher">
      <div className="activity-tabs">
        {examples.map((ex, i) => (
          <button
            key={ex.title}
            type="button"
            className={`activity-tab${i === active ? " is-active" : ""}`}
            aria-pressed={i === active}
            onClick={() => setActive(i)}
          >
            <span className="activity-tab-icon" aria-hidden="true">
              {ex.icon}
            </span>
            {ex.title}
          </button>
        ))}
      </div>

      <div key={current.title} className={`activity-panel color-${pillar.color}`}>
        <span className="activity-panel-icon" aria-hidden="true">
          {current.icon}
        </span>
        <h2>{current.title}</h2>
        {current.intro && <p className="activity-intro">{current.intro}</p>}
        <ul className="activity-tags">
          {current.tags.map((tag) => (
            <li key={tag}>{tag}</li>
          ))}
        </ul>
        <blockquote className="activity-quote">“{current.quote}”</blockquote>
      </div>
    </section>
  );
}
