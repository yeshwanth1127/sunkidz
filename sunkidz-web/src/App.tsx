import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { Layout } from "./components/Layout";
import { About } from "./pages/About";
import { Approach } from "./pages/Approach";
import { ApproachDetail } from "./pages/ApproachDetail";
import { Branches } from "./pages/Branches";
import { Enquire } from "./pages/Enquire";
import { Home } from "./pages/Home";
import { Programs } from "./pages/Programs";

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<Home />} />
          <Route path="about" element={<About />} />
          <Route path="programs" element={<Programs />} />
          <Route path="approach" element={<Approach />} />
          <Route path="approach/:pillarId" element={<ApproachDetail />} />
          <Route path="branches" element={<Branches />} />
          <Route path="enquire" element={<Enquire />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
