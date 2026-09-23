import { Link } from "react-router-dom";
import { branches, contact, tagline } from "../data/content";
import { BrandMark } from "./Brand";
import "./Brand.css";
import "./Footer.css";

export function Footer() {
  return (
    <footer className="footer">
      <div className="container footer-grid">
        <div className="footer-brand">
          <Link to="/" className="footer-logo-link" aria-label="SunKidz home">
            <BrandMark size={64} className="footer-sun" />
          </Link>
          <p className="footer-name">Sun Kidz</p>
          <p className="footer-tag">{tagline}</p>
          <p className="footer-meta">
            Preschool · Day care · Summer camps · Bangalore
          </p>
        </div>

        <div>
          <h3 className="footer-heading">Explore</h3>
          <ul className="footer-links">
            <li>
              <Link to="/about">About</Link>
            </li>
            <li>
              <Link to="/programs">Programs</Link>
            </li>
            <li>
              <Link to="/approach">Approach</Link>
            </li>
            <li>
              <Link to="/enquire">Enquire</Link>
            </li>
          </ul>
        </div>

        <div>
          <h3 className="footer-heading">Branches</h3>
          <ul className="footer-links">
            {branches.map((b) => (
              <li key={b.id}>
                <Link to="/branches">{b.name}</Link>
              </li>
            ))}
          </ul>
        </div>

        <div>
          <h3 className="footer-heading">Contact</h3>
          <ul className="footer-links">
            {contact.phones.map((p) => (
              <li key={p}>
                <a href={`tel:${p.replace(/\s/g, "")}`}>{p}</a>
              </li>
            ))}
            <li>
              <a href={`mailto:${contact.email}`}>{contact.email}</a>
            </li>
          </ul>
        </div>
      </div>
      <div className="container footer-bottom">
        <p>© {new Date().getFullYear()} SunKidz. All rights reserved.</p>
      </div>
    </footer>
  );
}
