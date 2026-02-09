// This file contains build-time constants
// __BUILD_TIMESTAMP__ is injected by Vite at build time
export const BUILD_TIMESTAMP = typeof __BUILD_TIMESTAMP__ !== 'undefined' ? __BUILD_TIMESTAMP__ : new Date().toISOString();
