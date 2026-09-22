import { Link } from "react-router-dom";
import { PillarGrid } from "../components/PillarGrid";
import { Section } from "../components/Section";
import { BrandMark } from "../components/Brand";
import "../components/Brand.css";
import {
  brandLine,
  brandSupport,
  branches,
  contact,
  programs,
  tagline,
} from "../data/content";
import "./Home.css";

export function Home() {
  return (
    <>
      <section className="hero">
        <div className="container hero-grid">
          <div className="hero-content">
            <h1 className="hero-headline">{brandLine}</h1>
            <p className="hero-support">{brandSupport}</p>
            <div className="btn-row">
              <Link to="/enquire" className="btn btn-primary">
                Enquire
              </Link>
              <a href={`tel:${contact.phoneTel}`} className="btn btn-secondary">
                Call us
              </a>
            </div>
          </div>
          <div className="hero-mark" aria-hidden="true">
            <BrandMark size={280} className="hero-sun" />
          </div>
        </div>
      </section>

      <Section
        label="Our approach"
        title="Four pillars of joyful learning"
        lead="The heart of SunKidz—experiential, social, wellness-led, and creative."
      >
        <PillarGrid compact />
        <p className="home-more">
          <Link to="/approach" className="text-link">
            Explore the approach →
          </Link>
        </p>
      </Section>

      <section className="section programs-strip">
        <div className="container">
          <span className="section-label">Programs</span>
          <h2 className="section-title">What we offer</h2>
          <div className="program-row">
            {programs.map((p) => (
              <Link
                key={p.id}
                to="/programs"
                className={`program-chip color-${p.color}`}
              >
                <strong>{p.name}</strong>
                <span>{p.blurb}</span>
              </Link>
            ))}
          </div>
        </div>
      </section>

      <Section
        label="Locations"
        title="Near you in Bangalore"
        lead="Three neighbourhood branches—visit the one closest to home."
      >
        <ul className="branch-preview">
          {branches.map((b) => (
            <li key={b.id}>
              <Link to="/branches">
                <strong>{b.name}</strong>
                <span>{b.address}</span>
              </Link>
            </li>
          ))}
        </ul>
      </Section>

      <section className="cta-band">
        <div className="container cta-band-inner">
          <p className="cta-tag">{tagline}</p>
          <h2>Ready to visit SunKidz?</h2>
          <p>Tell us about your child—we’ll help you find the right start.</p>
          <div className="btn-row">
            <Link to="/enquire" className="btn btn-primary btn-playful">
              Enquire now
            </Link>
            <Link to="/about" className="btn btn-secondary btn-playful">
              Our story
            </Link>
          </div>
        </div>
      </section>
    </>
  );
}
