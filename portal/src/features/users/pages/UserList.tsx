import { DataTable } from "@/components/data-table/data-table";
import { getUserColumn } from "../components/get-user-columns";
import { useNavigate } from "react-router";
import { Button } from "@/components/ui/button";
import { Loader2Icon, Search } from "lucide-react";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useCallback, useMemo, useState } from "react";
import { useGetData } from "@/lib/hooks";
import { itemStatusOptions, UserTypeOptions, type WhereCondition } from "@/lib/types";
import type { User } from "../types";
import DM_CORE_CONFIG from "@/constant";
import { useUser } from "@/hooks/use-user";
import { ChangePasswordModal } from "../components/change-password-modal";

const UserList = () => {
  const {user} = useUser();
  const navigate = useNavigate();
  const [pageIndex, setPageIndex] = useState(0);
  const pageSize = DM_CORE_CONFIG.PAGESIZE;
  const [filters, setFilters] = useState<WhereCondition[]>([]);

  const [userName, setUserName] = useState("");
  const [phone, setPhone] = useState("");
  const [status, setStatus] = useState("");
  const [type, setType] = useState("");
  const [passwordModalOpen, setPasswordModalOpen] = useState(false);
  const [selectedUser, setSelectedUser] = useState<User | null>(null);

  const onOpenPasswordModal = (user: User) => {
    setSelectedUser(user);
    setPasswordModalOpen(true);
  };



const columns = useMemo(
  () =>
    getUserColumn({
      navigate,
      currentUserType: user?.type!,
      onOpenPasswordModal,
    }),
  [navigate, user?.type]
);
  const { data, isLoading, isFetching } = useGetData<User[]>(
    "user",
    {
      limit: { offset: pageIndex * pageSize, total: pageSize },
      ...(filters.length > 0 ? { where: filters } : {}),
      order: { by: "id", type: "DESC" },
    },
    {
      keepPrevious: true,
    }
  );

  const handleSearch = useCallback(() => {
    const newFilters: WhereCondition[] = [];

    if (userName.trim()) {
      newFilters.push({ key: "name", operator: "like", value: userName });
    }
    if (phone.trim()) {
      newFilters.push({ key: "phone", operator: "like", value: phone });
    }
    if (status) {
      newFilters.push({ key: "status", operator: "is", value: status });
    }
    if (type) {
      newFilters.push({ key: "type", operator: "is", value: type });
    }

    setFilters(newFilters);
    setPageIndex(0);
  }, [userName, phone, status ,type]);

  return (
    <>
      <div className="max-w-4/5 w-4/5 mx-auto p-6 bg-sidebar rounded-lg">
        {/* Filters */}
        <div className="mb-6">
          <h1 className="uppercase text-xl text-primary font-medium tracking-tight mb-4">
            User List
          </h1>
          <div className="flex flex-wrap items-center justify-between gap-4 mb-4">
            {/* Filters */}
            <div className="flex flex-wrap items-center gap-4">
              <Input
                placeholder="Enter user name"
                value={userName}
                onChange={(e) => setUserName(e.target.value)}
                className="w-auto min-w-[180px]"
              />

              <Input
                placeholder="Enter phone number"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                className="w-auto min-w-[160px]"
              />

              <Select value={status} onValueChange={setStatus}>
                <SelectTrigger className="w-auto">
                  <SelectValue placeholder="Status" />
                </SelectTrigger>
                <SelectContent>
                  {itemStatusOptions.map((s) => (
                    <SelectItem key={s} value={s}>
                      {s.charAt(0).toUpperCase() + s.slice(1)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>

              <Select value={type} onValueChange={setType}>
                <SelectTrigger className="w-auto">
                  <SelectValue placeholder="Type" />
                </SelectTrigger>
                <SelectContent>
                  {UserTypeOptions.map((u) => (
                    <SelectItem key={u} value={u}>
                      {u}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>

              <Button
                onClick={handleSearch}
                variant="outline"
                className="w-auto"
              >
                {isFetching ? (
                  <Loader2Icon className="animate-spin" />
                ) : (
                  <Search />
                )}
                Search
              </Button>
            </div>

            {/* Action */}
            <div className="flex gap-2">
              <Button onClick={() => navigate("create")} className="w-auto">
                Create User
              </Button>
            </div>
          </div>
        </div>

        {/* Table */}
        <div className="bg-sidebar rounded-lg py-3">
          {isLoading ? (
            <div className="flex justify-center items-center py-20 text-muted-foreground">
              <Loader2Icon className="animate-spin w-8 h-8 mr-2" />
            </div>
          ) : (
            <DataTable
              data={data?.message ?? []}
              columns={columns}
              pageCount={Math.ceil((data?.count ?? 0) / pageSize)}
              pageIndex={pageIndex}
              onPageChange={setPageIndex}
            />
          )}
        </div>
      </div>
      <ChangePasswordModal
        open={passwordModalOpen}
        onClose={() => setPasswordModalOpen(false)}
        user={selectedUser}
      />
    </>
  );
};

export default UserList;
