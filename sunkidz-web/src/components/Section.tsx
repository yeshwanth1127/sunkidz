import type { ReactNode } from "react";

type Props = {
  label?: string;
  title: string;
  lead?: string;
  children?: ReactNode;
  className?: string;
};

export function Section({ label, title, lead, children, className = "" }: Props) {
  return (
    <section className={`section ${className}`.trim()}>
      <div className="container">
        {label && <span className="section-label">{label}</span>}
        <h2 className="section-title">{title}</h2>
        {lead && <p className="section-lead">{lead}</p>}
        {children}
      </div>
    </section>
  );
}
