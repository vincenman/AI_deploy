import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: 'export', // Static export: npm run build writes HTML/JS to out/
  trailingSlash: true, // Emit product/index.html so StaticFiles serves /product/ (and /product) correctly
  images: {
    unoptimized: true, // Required for static export
  },
  reactStrictMode: true,
};

export default nextConfig;
