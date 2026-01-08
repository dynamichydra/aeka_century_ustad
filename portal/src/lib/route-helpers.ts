import { navItem } from "@/config/navConfig";

// Given a route path (like "branch/request/create"), return its allowed roles
export function getAllowedRolesForPath(path: string): string[] | undefined {
  for (const item of navItem) {
    // Direct match
    if (item.url === path) return item.roles;

    // Dropdown items
    if (item.items) {
      const found = item.items.find((child) => child.url === path);
      if (found) return item.roles;
    }
  }
  return undefined;
}
