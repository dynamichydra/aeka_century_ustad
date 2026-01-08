import { useUser } from "@/hooks/use-user";
import ProfileForm from "../components/profile-form";
import { Loader2Icon } from "lucide-react";
import { useGetData } from "@/lib/hooks";
import type { User } from "../schema";

export default function ProfilePage() {
  const { user, isLoading } = useUser();
  const { data: userData, isLoading: isUsersLoading } = useGetData<User[]>(
    "user",
    {
      where: [{ key: "user##id", value: user!.id, operator: "is" }],
      reference: [
        {
          type: "JOIN",
          obj: "zip",
          a: "id",
          b: "user.zip",
        },
      ],
      select:
        "user.*, zip.code ziplabel",
    }
  );

  if (isLoading || isUsersLoading) {
    return (
      <div className="flex justify-center items-center py-20 text-muted-foreground">
        <Loader2Icon className="animate-spin w-8 h-8 mr-2" />
      </div>
    );
  }

  const users = userData?.message[0] ?? [];
  return (
    <div className="bg-sidebar rounded-lg p-6">
      <ProfileForm initial={users ?? undefined} />
    </div>
  );
}
