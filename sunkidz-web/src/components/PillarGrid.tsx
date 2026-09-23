import { Link } from "react-router-dom";
import { pillars, type Pillar } from "../data/content";
import "./PillarGrid.css";

type Props = {
  compact?: boolean;
};

export function PillarGrid({ compact = false }: Props) {
  return (
    <div className={`pillar-grid${compact ? " is-compact" : ""}`}>
      {pillars.map((pillar, i) => (
        <PillarCard key={pillar.id} pillar={pillar} delay={i * 80} compact={compact} />
      ))}
    </div>
  );
}

function PillarCard({
  pillar,
  delay,
  compact,
}: {
  pillar: Pillar;
  delay: number;
  compact: boolean;
}) {
  return (
    <Link
      to={`/approach/${pillar.id}`}
      className={`pillar-card color-${pillar.color} fade-up`}
      style={{ animationDelay: `${delay}ms` }}
    >
      <span className="pillar-icon" aria-hidden="true">
        {pillar.icon}
      </span>
      <span className="pillar-code">{pillar.code}</span>
      <h3 className="pillar-title">{pillar.title}</h3>
      <p className="pillar-summary">{pillar.summary}</p>
      {!compact && <span className="pillar-link">Explore {pillar.code} →</span>}
    </Link>
  );
}
