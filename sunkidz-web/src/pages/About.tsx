import { Link } from "react-router-dom";
import { BrandMark } from "../components/Brand";
import "../components/Brand.css";
import { about, developmentAreas, tagline } from "../data/content";
import "./InnerPages.css";

export function About() {
  return (
    <div className="page">
      <div className="container page-hero">
        <BrandMark size={72} className="page-brand-mark" />
        <span className="section-label">About</span>
        <h1>Our story</h1>
        <p>{about.story}</p>
      </div>

      <div className="container about-grid">
        <article className="about-block color-coral fade-up">
          <h2>Mission</h2>
          <p>{about.mission}</p>
        </article>
        <article className="about-block color-sky fade-up" style={{ animationDelay: "80ms" }}>
          <h2>Vision</h2>
          <p>{about.vision}</p>
        </article>
        <article className="about-block color-leaf fade-up" style={{ animationDelay: "160ms" }}>
          <h2>Wellness of society</h2>
          <p>{about.wellness}</p>
        </article>
        <article className="about-block color-sun fade-up" style={{ animationDelay: "240ms" }}>
          <h2>Every child unique</h2>
          <p>{about.uniqueness}</p>
        </article>
      </div>

      <section className="section">
        <div className="container">
          <span className="section-label">Must read</span>
          <h2 className="section-title">Foundations for Success</h2>
          <p className="section-lead">{about.foundations}</p>

          <h3 className="subhead">Key aspects we develop</h3>
          <ul className="dev-grid">
            {developmentAreas.map((d) => (
              <li key={d.name}>
                <strong>{d.name}</strong>
                <span>{d.note}</span>
              </li>
            ))}
          </ul>

          <p className="quote-line">“{tagline}”</p>
          <Link to="/enquire" className="btn btn-primary">
            Enquire about admission
          </Link>
        </div>
      </section>
    </div>
  );
}
