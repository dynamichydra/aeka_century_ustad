import UserForm from "../components/user-form";
import { useParams } from "react-router";
import { useGetData } from "@/lib/hooks";
import { Loader2Icon } from "lucide-react";
import type { User } from "../schema";
import type { Branch } from "@/features/branche/types";

const UserEdit = () => {
  const { id } = useParams<{ id: string }>();
  if (!id) return null;

  const { data: userData, isLoading } = useGetData<User[]>("user u", {
    where: [{ key: "u##id", value: id, operator: "is" }],
    reference: [
      {
        type: "LEFT JOIN",
        obj: "user_branch_access uba",
        a: "uba.user_id",
        b: "u.id",
      },
      {
        type: "LEFT JOIN",
        obj: "zip z",
        a: "z.id",
        b: "u.zip",
      },
    ],
    select:
      "u.id id, u.code code, u.name name, u.state state, u.city city, u.email email, u.phone phone, u.pwd pwd, u.zip zip, u.address address, u.created_by created_by, u.type type, uba.branch_id branch, uba.id uba_id, z.code ziplabel",
  });

  const users = userData?.message ?? [];
  const mergedUser: User | null =
    users.length > 0
      ? {
          ...users[0],
          branch: Array.from(
            new Set(
              users.map((u) => (u.branch !== null ? String(u.branch) : ""))
            )
          ).filter(Boolean),
          uba_id: Array.from(
            new Set(
              users.map((u) => (u.uba_id !== null ? String(u.uba_id) : ""))
            )
          ).filter(Boolean),
        }
      : null;

  const { data: branchData, isLoading: isBLoading } = useGetData<Branch[]>(
    "branch",
    { order: { by: "name", type: "ASC" } }
  );

  if (isLoading || isBLoading) {
    return (
      <div className="flex justify-center items-center py-20 text-muted-foreground">
        <Loader2Icon className="animate-spin w-8 h-8 mr-2" />
      </div>
    );
  }

  if (!mergedUser) {
    return <div className="text-center py-10">User not found</div>;
  }

  return (
    <div className="bg-sidebar rounded-lg">
      <UserForm
        mode="edit"
        user={mergedUser}
        branch={branchData?.message ?? []}
      />
    </div>
  );
};

export default UserEdit;
