import Script from "next/script";
import { TempoInit } from "./tempo-init";
import "./globals.css";

export const metadata = {
  title: "Best SaaS Kit Pro",
  description: "The best SaaS starter kit for your next project",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <Script src="https://api.tempolabs.ai/proxy-asset?url=https://storage.googleapis.com/tempo-public-assets/error-handling.js" />
        <TempoInit />
        {children}
      </body>
    </html>
  );
}
