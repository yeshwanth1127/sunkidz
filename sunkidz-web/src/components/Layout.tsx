import { Outlet } from "react-router-dom";
import { Header } from "./Header";
import { Footer } from "./Footer";
import { FloatingContact } from "./FloatingContact";
import { ScrollToTop } from "./ScrollToTop";

export function Layout() {
  return (
    <>
      <ScrollToTop />
      <Header />
      <main className="site-main">
        <Outlet />
      </main>
      <Footer />
      <FloatingContact />
    </>
  );
}
