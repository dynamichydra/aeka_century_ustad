import { Badge } from "@/components/ui/badge";
import { CheckCircle2, Clock, XCircle, Ban, Loader } from "lucide-react";
import React from "react";

export type AppStatus =
  | "pending"
  | "active"
  | "1"
  | "accepted"
  | "inactive"
  | "deleted"
  | "approve"
  | "approved"
  | "completed"
  | "manufacturing"
  | "request"
  | "approval"
  | "reject"
  | "rejected"
  | "rejection"
  | "delivery"
  | "receive"
  | "received"
  | "manufacture"
  | "ready_for_receive"
  | "done"
  | "partial";

const statusMap: Record<
  AppStatus,
  { label: string; color: string; icon: React.ElementType }
> = {
  pending: {
    label: "Pending",
    color: "bg-yellow-100 text-yellow-800",
    icon: Clock,
  },
  manufacture: {
    label: "Manufacture",
    color: "bg-yellow-100 text-yellow-800",
    icon: Clock,
  },
  active: {
    label: "Active",
    color: "bg-green-100 text-green-800",
    icon: CheckCircle2,
  },
  completed: {
    label: "Completed",
    color: "bg-green-100 text-green-800",
    icon: CheckCircle2,
  },
  accepted: {
    label: "Accepted",
    color: "bg-green-100 text-green-800",
    icon: CheckCircle2,
  },
  inactive: {
    label: "Inactive",
    color: "bg-gray-100 text-gray-800",
    icon: Ban,
  },
  deleted: {
    label: "Deleted",
    color: "bg-red-100 text-red-800",
    icon: XCircle,
  },
  approve: {
    label: "Approved",
    color: "bg-blue-100 text-blue-800",
    icon: CheckCircle2,
  },
  approved: {
    label: "Approved",
    color: "bg-blue-100 text-blue-800",
    icon: CheckCircle2,
  },
  manufacturing: {
    label: "Manufacturing",
    color: "bg-purple-100 text-purple-800",
    icon: Loader,
  },
  1: {
    label: "Active",
    color: "bg-green-100 text-green-800",
    icon: CheckCircle2,
  },
  request: {
    label: "Request",
    color: "bg-yellow-100 text-yellow-800",
    icon: Clock,
  },
  approval: {
    label: "Approval",
    color: "bg-blue-100 text-blue-800",
    icon: CheckCircle2,
  },
  reject: {
    label: "Rejection",
    color: "bg-red-100 text-red-800",
    icon: XCircle,
  },
  rejected: {
    label: "Rejection",
    color: "bg-red-100 text-red-800",
    icon: XCircle,
  },
  rejection: {
    label: "Rejection",
    color: "bg-red-100 text-red-800",
    icon: XCircle,
  },
  delivery: {
    label: "Delivery",
    color: "bg-purple-100 text-purple-800",
    icon: Loader,
  },
  receive: {
    label: "Received",
    color: "bg-green-100 text-green-800",
    icon: CheckCircle2,
  },
  received: {
    label: "Received",
    color: "bg-green-100 text-green-800",
    icon: CheckCircle2,
  },
  ready_for_receive: {
    label: "Ready for Receive",
    color: "bg-blue-100 text-blue-800",
    icon: CheckCircle2,
  },
  partial: {
    label: "Partial",
    color: "bg-orange-200 text-orange-800",
    icon: Loader,
  },
  done: {
    label: "Done",
    color: "bg-green-100 text-green-800",
    icon: CheckCircle2,
  },
};

export function StatusBadge({
  value,
  late,
}: {
  value: AppStatus;
  late?: boolean;
}) {
  // console.log('StatusBadge value:', value);
  // const cfg = statusMap[(typeof value === "string" ? value.toLowerCase() : value) as AppStatus] || {
  //   label: "Unknown",
  //   color: "bg-gray-100 text-gray-800",
  //   icon: XCircle,
  // };
  const cfg =
    statusMap[
      (typeof value === "string" ? value.toLowerCase() : value) as AppStatus
    ];
  const Icon = cfg.icon;
  return (
    <Badge
      variant="outline"
      className={`flex items-center gap-1 ${
        late ? "bg-red-100 text-red-800" : cfg.color
      }`}
    >
      <Icon className="h-4 w-4" />
      <span>{cfg.label}</span>
    </Badge>
  );
}
