import type { ColumnDef } from "@tanstack/react-table";
import type { User } from "../types";
import type { ItemStatus } from "@/lib/types";

import { Button } from "@/components/ui/button";
import {type NavigateFunction } from "react-router";
import { Edit2Icon, Lock } from "lucide-react";
import { StatusBadge } from "@/lib/app-status";

export const getUserColumn = ({
  navigate,
  currentUserType,
  onOpenPasswordModal,
}: {
  navigate: NavigateFunction;
  currentUserType: string;
  onOpenPasswordModal: (user: User) => void;
}): ColumnDef<User>[] => {
  const columns: ColumnDef<User>[] = [
    {
      accessorKey: "name",
      header: "Name",
    },
    {
      accessorKey: "code",
      header: "Code",
    },
    {
      accessorKey: "phone",
      header: "Phone",
    },
    {
      accessorKey: "email",
      header: "Email",
    },
    {
      accessorKey: "type",
      header: "Type",
    },
    {
      accessorKey: "address",
      header: "Address",
    },
    {
      accessorKey: "status",
      header: "Status",
      cell: ({ getValue }) => <StatusBadge value={getValue<ItemStatus>()} />,
    },
    {
      id: "actions",
      header: "Actions",
      cell: ({ row }) => {
        const link = `edit/${row.original.id}`;
        return (
          <div className="flex justify-center items-center gap-2">
            <Button variant={"outline"} onClick={() => navigate(link)}>
              <Edit2Icon />
            </Button>
            {currentUserType === "Admin" && (
              <Button
                variant="outline"
                onClick={() => onOpenPasswordModal(row.original)}
              >
                <Lock />
              </Button>
            )}
          </div>
        );
      },
    },
  ];
  return columns;
};