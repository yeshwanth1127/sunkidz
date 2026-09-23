import { NavLink, Link } from "react-router-dom";
import { useState } from "react";
import { navLinks } from "../data/content";
import { BrandWordmark } from "./Brand";
import "./Brand.css";
import "./Header.css";

export function Header() {
  const [open, setOpen] = useState(false);

  return (
    <header className="header">
      <div className="container header-inner">
        <Link
          to="/"
          className="logo"
          aria-label="SunKidz — home"
          onClick={() => setOpen(false)}
        >
          <BrandWordmark className="logo-wordmark" />
        </Link>

        <button
          type="button"
          className={`nav-toggle${open ? " is-open" : ""}`}
          aria-label={open ? "Close menu" : "Open menu"}
          aria-expanded={open}
          onClick={() => setOpen((v) => !v)}
        >
          <span />
          <span />
        </button>

        <nav className={`nav${open ? " is-open" : ""}`} aria-label="Main">
          {navLinks.map((link) => (
            <NavLink
              key={link.to}
              to={link.to}
              className={({ isActive }) =>
                `nav-link${isActive ? " is-active" : ""}`
              }
              onClick={() => setOpen(false)}
            >
              {link.label}
            </NavLink>
          ))}
          <Link
            to="/enquire"
            className="btn btn-primary nav-cta"
            onClick={() => setOpen(false)}
          >
            Enquire
          </Link>
        </nav>
      </div>
    </header>
  );
}
