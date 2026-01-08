import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import {
  Table,
  TableHeader,
  TableRow,
  TableHead,
  TableCell,
  TableBody,
} from "@/components/ui/table";
import { Link } from "react-router";
import { Button } from "@/components/ui/button";
import moment from "moment";
import { useGetCustomData } from "@/lib/hooks";
import clsx from "clsx";

const RequestTable = ({
  uId,
  type,
  branch,
}: {
  uId: number;
  type: string;
  branch: number;
}) => {
  const { data } = useGetCustomData<any[]>("dashboard", {
    type: "request_table",
    uId: uId,
    branch: branch,
    uType: type,
  });
  let requests = [];
  if (data && data.message && data.message.length > 0) {
    requests = data.message;
  }

  const reClass = clsx("col-span-12", {
    "md:col-span-12": type === "Sales",
    "md:col-span-6": type !== "Sales",
  });

  return (
    <Card className={reClass}>
      <CardHeader className="flex justify-between items-center">
        <CardTitle>Sample Request</CardTitle>
        { (type == "Sales" || type === "BAT") && (
          <Link to={type == "Sales" ? "salesrequest" : "/branch/request"}>
            <Button
              variant="outline"
              size="sm"
              className="mt-2 text-xs rounded-xl"
            >
              View details
            </Button>
          </Link>
        )}
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>By</TableHead>
              <TableHead>For</TableHead>
              <TableHead>Lead No</TableHead>
              <TableHead>Total</TableHead>
              <TableHead>Date</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {requests.map((request) => (
              <TableRow key={request.id}>
                <TableCell>{request.request_by}</TableCell>
                <TableCell>{request.request_for}</TableCell>
                <TableCell>{request.lead_no}</TableCell>
                <TableCell>{request.total}</TableCell>
                <TableCell>
                  {moment(request.created_at).format("DD/MM/YYYY")}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
};

export default RequestTable;
