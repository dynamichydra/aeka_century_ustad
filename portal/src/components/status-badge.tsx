import { Badge } from "@/components/ui/badge";

interface StatusBadgeProps {
  status: string;
}

export function StatusBadge({ status }: StatusBadgeProps) {
  const normalized = status?.toLowerCase();

  switch (normalized) {
    case "active":
      return (
        <Badge
          variant="outline"
          className="bg-green-100 text-green-700 border-green-300 font-medium px-3 py-1 rounded-sm"
        >
          Active
        </Badge>
      );

    case "inactive":
      return (
        <Badge
          variant="outline"
          className="bg-red-100 text-red-700 border-red-300 font-medium px-3 py-1 rounded-sm"
        >
          Inactive
        </Badge>
      );

    // === 📝 Future statuses (just uncomment and style as needed) ===
    // case "pending":
    //   return (
    //     <Badge
    //       variant="outline"
    //       className="bg-yellow-100 text-yellow-700 border-yellow-300 font-medium px-3 py-1 rounded-sm"
    //     >
    //       Pending
    //     </Badge>
    //   );

    // case "deleted":
    //   return (
    //     <Badge
    //       variant="outline"
    //       className="bg-gray-100 text-gray-700 border-gray-300 font-medium px-3 py-1 rounded-sm"
    //     >
    //       Deleted
    //     </Badge>
    //   );

    default:
      return (
        <Badge
          variant="outline"
          className="bg-gray-100 text-gray-600 border-gray-300 font-medium px-3 py-1 rounded-sm"
        >
          {status || "Unknown"}
        </Badge>
      );
  }
}
