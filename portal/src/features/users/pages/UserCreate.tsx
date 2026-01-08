import { useGetData } from "@/lib/hooks";
import UserForm from "../components/user-form"
import type { Branch } from "@/features/branche/types";
import { Loader2Icon } from "lucide-react";

const UserCreate = () => {
  const { data, isLoading } = useGetData<Branch[]>("branch", {
    order: { by: "name", type: "ASC" },
  });

  if (isLoading) {
    return (
      <div className="flex justify-center items-center py-20 text-muted-foreground">
        <Loader2Icon className="animate-spin w-8 h-8 mr-2" />
      </div>
    );
  }
  return (
    <div className="bg-sidebar rounded-lg">
      <UserForm mode="create" branch={data?.message ?? []}/>
    </div>
  );
}

export default UserCreate