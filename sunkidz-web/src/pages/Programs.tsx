import { Link } from "react-router-dom";
import { programs } from "../data/content";
import "./InnerPages.css";

export function Programs() {
  return (
    <div className="page">
      <div className="container page-hero fade-up">
        <span className="section-label">Programs</span>
        <h1>Learning that fits your child’s day</h1>
        <p>
          Preschool foundations, caring daycare, and lively summer camps—each
          designed around play, discovery, and belonging.
        </p>
      </div>

      <div className="container program-list">
        {programs.map((p, i) => (
          <article
            key={p.id}
            className={`program-panel color-${p.color} fade-up`}
            style={{ animationDelay: `${i * 90}ms` }}
          >
            <h2>{p.name}</h2>
            <p className="program-blurb">{p.blurb}</p>
            <ul className="bullet-list">
              {p.points.map((point) => (
                <li key={point}>{point}</li>
              ))}
            </ul>
          </article>
        ))}
      </div>

      <div className="container page-cta">
        <p>Not sure which program fits? We’ll help you choose.</p>
        <div className="btn-row">
          <Link to="/enquire" className="btn btn-primary">
            Enquire
          </Link>
          <Link to="/approach" className="btn btn-secondary">
            See our approach
          </Link>
        </div>
      </div>
    </div>
  );
}
