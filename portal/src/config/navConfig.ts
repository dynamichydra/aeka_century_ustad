import {
  type LucideIcon,
  Home,
  User,
} from "lucide-react";
type NavType = {
  title: string;
  roles?: string[];
  url: string;
  icon?: LucideIcon;
  isActive?: boolean;
  type: "dropdown" | "regular";
  items?: {
    title: string;
    url: string;
  }[];
};
export const navItem: NavType[] = [
  {
    title: "Home",
    url: "/",
    icon: Home,
    isActive: true,
    type: "regular",
  },
  {
    title: "User",
    url: "/user",
    icon: User,
    isActive: false,
    type: "regular",
  }
];