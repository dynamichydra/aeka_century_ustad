import * as React from "react";
import { LogOut } from "lucide-react";

import { NavProjects } from "@/components/nav-projects";
import icon from "@/assets/centuryply_icon.png";
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarRail,
} from "@/components/ui/sidebar";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { TeamSwitcher } from "./team-switcher";
import { LogOut as logOutApi } from "@/features/auth/api";
import { navItem } from "@/config/navConfig";
import { NavMain } from "./nav-main";

type AppSidebarProps = React.ComponentProps<typeof Sidebar> & {
  userType: string;
};

export function AppSidebar({ userType, ...props }: AppSidebarProps) {
  return (
    <Sidebar collapsible="icon" {...props}>
      <SidebarHeader>
        <TeamSwitcher
          teams={{
            name: "CENTURYPLY",
            logo: icon,
            plan: "",
          }}
        />
      </SidebarHeader>
      <SidebarContent>
        {navItem
          .filter((item) => item.roles?.includes(userType) ?? true)
          .map((nav) => {
            if (nav.type === "dropdown") {
              return <NavMain items={nav} key={nav.title} />;
            } else {
              return <NavProjects projects={nav} key={nav.title} />;
            }
          })}
      </SidebarContent>
      <SidebarFooter>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton
              size="lg"
              className="data-[state=open]:bg-sidebar-accent data-[state=open]:text-sidebar-accent-foreground flex items-center gap-3 text-primary cursor-pointer"
              onClick={logOutApi}
            >
              <Avatar className="size-5 rounded-lg">
                <AvatarFallback className="rounded-lg">
                  <LogOut />
                </AvatarFallback>
              </Avatar>
              <span className="truncate font-medium">Log out</span>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
  );
}
