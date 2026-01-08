import { useUser } from "@/hooks/use-user";
import ProfileForm from "../components/profile-form";
import { Loader2Icon } from "lucide-react";
import { useGetData } from "@/lib/hooks";
import type { Branch } from "@/features/branche/types";
import type { User } from "../schema";

export default function ProfilePage() {
  const { user, isLoading } = useUser();

  if (isLoading) {
    return (
      <div className="flex justify-center items-center py-20 text-muted-foreground">
        <Loader2Icon className="animate-spin w-8 h-8 mr-2" />
      </div>
    );
  }

  if (!user) {
    return <span className="text-red-500">User Not Found</span>;
  }

  const { data: userData, isLoading: isUsersLoading } = useGetData<User[]>(
    "user u",
    {
      where: [{ key: "u##id", value: user.id, operator: "is" }],
      reference: [
        {
          type: "LEFT JOIN",
          obj: "user_branch_access uba",
          a: "uba.user_id",
          b: "u.id",
        },
        {
          type: "JOIN",
          obj: "zip z",
          a: "z.id",
          b: "u.zip",
        },
      ],
      select:
        "u.id id, u.code code, u.name name, u.state state, u.city city, u.email email, u.phone phone, u.pwd pwd, u.zip zip, u.address address, u.created_by created_by, u.type type, uba.branch_id branch, uba.id uba_id, z.code ziplabel",
    }
  );

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

  console.log("user");
  console.log(mergedUser);
  console.log("user");

  const { data: branch, isLoading: isBLoading } = useGetData<Branch[]>(
    "branch",
    { order: { by: "name", type: "ASC" } }
  );

  if (isLoading || isUsersLoading || isBLoading) {
    return (
      <div className="flex justify-center items-center py-20 text-muted-foreground">
        <Loader2Icon className="animate-spin w-8 h-8 mr-2" />
      </div>
    );
  }

  return (
    <div className="bg-sidebar rounded-lg p-6">
      <ProfileForm initial={mergedUser ?? undefined} branch={branch?.message ?? []} />
    </div>
  );
}
