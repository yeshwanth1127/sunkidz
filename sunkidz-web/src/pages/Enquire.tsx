import { EnquireForm } from "../components/EnquireForm";
import { BrandMark } from "../components/Brand";
import "../components/Brand.css";
import { contact } from "../data/content";
import "./InnerPages.css";

export function Enquire() {
  return (
    <div className="page">
      <div className="container enquire-layout">
        <div className="page-hero">
          <BrandMark size={88} className="page-brand-mark" />
          <span className="section-label">Enquire</span>
          <h1>Start a conversation</h1>
          <p>
            Share a few details and we’ll get back to you. Prefer to talk?
            Call{" "}
            <a className="inline-phone" href={`tel:${contact.phoneTel}`}>
              {contact.phones[0]}
            </a>
            .
          </p>
        </div>
        <EnquireForm />
      </div>
    </div>
  );
}
