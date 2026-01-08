import { AppSidebar } from "@/components/app-sidebar";
import {
  SidebarInset,
  SidebarProvider,

} from "@/components/ui/sidebar";
import { Outlet, } from "react-router";
import Header from "./header";
import { useUser } from "@/hooks/use-user";


export function dashboard() {
  const { user } = useUser();



  return (
    <SidebarProvider>
      <AppSidebar userType={user?.type as string} />
      <SidebarInset>
        <Header />
        <div className="flex flex-1 flex-col gap-4 p-4 bg-secondary mt-16">
          <Outlet />
        </div>
      </SidebarInset>
    </SidebarProvider>
  );
}
