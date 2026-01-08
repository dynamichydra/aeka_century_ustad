// lib/all-lucide-icons.ts
import * as Icons from "lucide-react";
import type { LucideIcon } from "lucide-react";

export type IconEntry = {
  /** kebab-case icon name to store in DB, e.g. "arrow-right-circle" */
  name: string;
  /** React component */
  component: LucideIcon;
};

/** Convert PascalCase to kebab-case */
function pascalToKebab(name: string) {
  return name
    .replace(/([a-z0-9])([A-Z])/g, "$1-$2")
    .replace(/([A-Z])([A-Z][a-z])/g, "$1-$2")
    .toLowerCase();
}

// `Icons` has some non-icon exports, so go via `unknown`
const rawIcons = Icons as unknown as Record<string, LucideIcon>;

export const ALL_LUCIDE_ICONS: IconEntry[] = Object.entries(rawIcons)
  // Filter out non-component exports & weird keys
  .filter(([key, value]) => {
    if (key === "default" || key === "createLucideIcon") return false;
    // keep only functions (React components)
    return typeof value === "function";
  })
  .map(([pascalName, component]) => ({
    name: pascalToKebab(pascalName), // store this in DB
    component,
  }))
  // just to keep it stable
  .sort((a, b) => a.name.localeCompare(b.name));
