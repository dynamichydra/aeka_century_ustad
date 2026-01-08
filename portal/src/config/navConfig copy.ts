import { Settings2, type LucideIcon, User2, Building2, Home } from "lucide-react"; 
 type NavType = {
    title: string
    url: string
    icon?: LucideIcon
    isActive?: boolean,
    type: 'dropdown' | 'regular'
    items?: {
      title: string
      url: string
    }[]
  }
export const navItem: NavType[] = [
  {
    title: "Home",
    url: "/home",
    icon: Home,
    isActive: true,
    type: "regular",
  },
  {
    title: "User",
    url: "/home/user",
    icon: User2,
    isActive: true,
    type: "regular",
  },
  {
    title: "Branch",
    url: "home/branch",
    icon: Building2,
    isActive: true,
    type: "dropdown",
    items: [
      { title: "User", url: "branch/user" },
      { title: "List", url: "branch/list" },
      { title: "Request", url: "branch/request" },
      { title: "Stock", url: "branch/stock" },
      { title: "Order", url: "branch/order" },
    ],
  },
  {
    title: "Settings",
    url: "home/settings",
    icon: Settings2,
    type: "dropdown",
    items: [
      { title: "General", url: "settings/general" },
      { title: "Notification", url: "settings/notification" },
      { title: "Product", url: "settings/product" },
    ],
  },
];
