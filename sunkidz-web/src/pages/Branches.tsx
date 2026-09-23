import { Link } from "react-router-dom";
import { branches, contact } from "../data/content";
import "./InnerPages.css";

export function Branches() {
  return (
    <div className="page">
      <div className="container page-hero fade-up">
        <span className="section-label">Branches</span>
        <h1>Find SunKidz near you</h1>
        <p>
          Three Bangalore locations. Call or message us—we’ll help you plan a
          visit.
        </p>
      </div>

      <div className="container branch-list">
        {branches.map((b, i) => (
          <article
            key={b.id}
            className={`branch-card fade-up${b.primary ? " is-primary" : ""}`}
            style={{ animationDelay: `${i * 90}ms` }}
          >
            {b.primary && <span className="branch-badge">Flagship</span>}
            <h2>{b.name}</h2>
            <p className="branch-address">{b.address}</p>
            <div className="branch-actions">
              <a
                className="btn btn-secondary"
                href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(b.mapQuery)}`}
                target="_blank"
                rel="noreferrer"
              >
                Open map
              </a>
              <a className="btn btn-ghost" href={`tel:${contact.phoneTel}`}>
                Call
              </a>
            </div>
          </article>
        ))}
      </div>

      <div className="container contact-strip">
        <h2>Contact</h2>
        <ul className="contact-lines">
          {contact.phones.map((p) => (
            <li key={p}>
              <a href={`tel:${p.replace(/\s/g, "")}`}>{p}</a>
            </li>
          ))}
          <li>
            <a href={`mailto:${contact.email}`}>{contact.email}</a>
          </li>
        </ul>
        <Link to="/enquire" className="btn btn-primary">
          Enquire online
        </Link>
      </div>
    </div>
  );
}
