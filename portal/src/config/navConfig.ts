import { Settings2, View, FilePlus2, ListOrdered, Blocks, type LucideIcon, Building2, Home, MapIcon, BookMarkedIcon } from "lucide-react"; 
 type NavType = {
    title: string
    roles?: string[]
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
    url: "/",
    icon: Home,
    isActive: true,
    type: "regular",
  },
  {
    title: "Create Sample Request",
    url: "branch/request/create",
    icon: FilePlus2,
    isActive: true,
    type: "regular",
    roles: ["Sales"],
  },
  {
    title: "Sample Requests",
    url: "branch/request",
    icon: View,
    isActive: true,
    type: "regular",
    roles: ["BAT"],
  },
  {
    title: "Requests List",
    url: "salesrequest",
    icon: View,
    isActive: true,
    type: "regular",
    roles: ["Sales"],
  },
  {
    title: "Factory Orders",
    url: "branch/order",
    icon: ListOrdered,
    isActive: true,
    type: "regular",
    roles: ["Admin", "BAT", "PMG", "Commercial", "Factory"],
  },
  {
    title: "Damage Book",
    url: "damagebook",
    icon: BookMarkedIcon,
    isActive: true,
    type: "regular",
    roles: ["Admin", "BAT", "PMG", "Commercial", "Factory"],
  },
  {
    title: "Stock Report",
    url: "branch/stock",
    icon: Blocks,
    isActive: true,
    type: "regular",
    roles: ["Admin", "BAT", "PMG", "Commercial", "Factory"],
  },
  {
    title: "Master",
    url: "branch",
    icon: Building2,
    isActive: false,
    type: "dropdown",
    roles: ["Admin"],
    items: [
      { title: "Influencer Management ", url: "influencer" },
      { title: "Project Management ", url: "project" },
      { title: "Product Management ", url: "product" },
      { title: "Branch Management ", url: "branch/list" },
      { title: "User Management", url: "user" },
    ],
  },
  {
    title: "Location",
    url: "location",
    icon: MapIcon,
    isActive: false,
    type: "dropdown",
    roles: ["Admin"],
    items: [
      { title: "State Management", url: "location/state" },
      { title: "City Management ", url: "location/city" },
      { title: "Pin Management ", url: "location/pin" },
      { title: "Region Management ", url: "location/region" },
    ],
  },
  {
    title: "Settings",
    url: "settings",
    icon: Settings2,
    isActive: false,
    type: "dropdown",
    roles: ["Admin"],
    items: [
      { title: "General", url: "settings/general" },
      { title: "Notification", url: "settings/notification" },
      { title: "Remarks Note", url: "settings/notes" },
    ],
  },
];
