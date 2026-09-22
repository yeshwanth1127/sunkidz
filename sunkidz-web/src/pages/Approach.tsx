import { PillarGrid } from "../components/PillarGrid";
import "./InnerPages.css";

export function Approach() {
  return (
    <div className="page">
      <div className="container page-hero fade-up">
        <span className="section-label">Approach</span>
        <h1>How children learn at SunKidz</h1>
        <p>
          Four pillars guide every day—hands-on experience, social growth,
          wellness, and creative application. Tap a pillar to see it in
          action.
        </p>
      </div>

      <div className="container">
        <PillarGrid />
      </div>
    </div>
  );
}
