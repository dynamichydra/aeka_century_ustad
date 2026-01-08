import UserForm from "../components/user-form";
import { useParams } from "react-router";
import { useGetData } from "@/lib/hooks";
import { Loader2Icon } from "lucide-react";
import type { User } from "../schema";

const UserEdit = () => {
  const { id } = useParams<{ id: string }>();
  if (!id) return null;

  const { data: userData, isLoading } = useGetData<User[]>("user", {
    where: [{ key: "user##id", value: id, operator: "is" }],
    reference: [
      {
        type: "LEFT JOIN",
        obj: "zip",
        a: "id",
        b: "user.zip",
      },
    ],
    select:
      "user.*, zip.code ziplabel",
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
      <UserForm
        mode="edit"
        user={userData?.message[0] ?? []}
      />
    </div>
  );
};

export default UserEdit;
