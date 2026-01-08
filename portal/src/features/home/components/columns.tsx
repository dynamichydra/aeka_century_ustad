import type{ ColumnDef } from "@tanstack/react-table";

// This type is used to define the shape of our data.
// You can use a Zod schema here if you want.
type Address ={
  village:string,
  pin:number
}
export type Payment = {
  id: string;
  amount: number;
  status: "pending" | "processing" | "success" | "failed";
  email: string;
  address?: Address;
};

import ActionsCell from "./ActionsCell";
// import { deleteUser } from "@/lib/api";
const handleDeleteUser = (id: string) => {
 console.log(id);
};

export const columns: ColumnDef<Payment>[] = [
  {
    accessorKey: "email",
    header: "Email",
  },
  {
    accessorKey: "amount",
    header: "Amount",
  },
  {
    accessorKey: "address.village",
    header: "Village",
  },
  {
    accessorKey: "status",
    header: "Status",
  },
  {
    id: "actions",
    header: "Actions",
    cell: ({ row }) => (
      <ActionsCell
        key={row.original.id}
        user={row.original}
        onDelete={handleDeleteUser}
      />
    ),
  },
];

