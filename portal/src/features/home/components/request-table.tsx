import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import {
  Table,
  TableHeader,
  TableRow,
  TableHead,
  TableCell,
  TableBody,
  TableFooter,
} from "@/components/ui/table";
import { Link } from "react-router";
import { Button } from "@/components/ui/button";

const RequestTable = () => {
 const departmentWiseSales = [
  {
    id: 1,
    department: "Pathology",
    testCount: 12,
    centerSale: 3500,
    corporate: 1200,
    digital: 800,
    referral: 500,
    netSale: 6000,
  },
  {
    id: 2,
    department: "Radiology",
    testCount: 9,
    centerSale: 2800,
    corporate: 1000,
    digital: 600,
    referral: 400,
    netSale: 4800,
  },
  {
    id: 3,
    department: "Cardiology",
    testCount: 6,
    centerSale: 2000,
    corporate: 800,
    digital: 500,
    referral: 300,
    netSale: 3600,
  },
  {
    id: 4,
    department: "Neurology",
    testCount: 22,
    centerSale: 1500,
    corporate: 600,
    digital: 400,
    referral: 200,
    netSale: 2700,
  },
  {
    id: 5,
    department: "Orthopedics",
    testCount: 25,
    centerSale: 2400,
    corporate: 900,
    digital: 500,
    referral: 250,
    netSale: 4050,
  }
];
  const totals = departmentWiseSales.reduce(
    (acc, curr) => {
      acc.testCount += curr.testCount;
      acc.centerSale += curr.centerSale;
      acc.corporate += curr.corporate;
      acc.digital += curr.digital;
      acc.referral += curr.referral;
      acc.netSale += curr.netSale;
      return acc;
    },
    {
      testCount: 0,
      centerSale: 0,
      corporate: 0,
      digital: 0,
      referral: 0,
      netSale: 0,
    }
  );

  // 🪙 Helper for formatting currency
  const formatCurrency = (value: number) =>
    value.toLocaleString("en-IN", { style: "currency", currency: "INR" });
  return (
    <Card className="col-span-12 md:col-span-6">
      <CardHeader className="flex justify-between items-center">
        <CardTitle>Department Wise Sales</CardTitle>
        <Link to={"/branch/request"}>
          <Button
            variant="outline"
            size="sm"
            className="mt-2 text-xs rounded-xl"
          >
            View details
          </Button>
        </Link>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader className="bg-accent">
            <TableRow>
              <TableHead>Deperment</TableHead>
              <TableHead>Test Count</TableHead>
              <TableHead>Center Sale</TableHead>
              <TableHead>Corporate</TableHead>
              <TableHead>Digital</TableHead>
              <TableHead>Referal</TableHead>
              <TableHead>Net Sale</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {departmentWiseSales.map((request) => (
              <TableRow key={request.id}>
                <TableCell>{request.department}</TableCell>
                <TableCell>{request.testCount}</TableCell>
                <TableCell>{formatCurrency(request.centerSale)}</TableCell>
                <TableCell>{formatCurrency(request.corporate)}</TableCell>
                <TableCell>{formatCurrency(request.digital)}</TableCell>
                <TableCell>{formatCurrency(request.referral)}</TableCell>
                <TableCell className="font-semibold">
                  {formatCurrency(request.netSale)}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
          <TableFooter>
            <TableRow className="font-semibold bg-primary/25">
              <TableCell>Today's Sale</TableCell>
              <TableCell>{totals.testCount}</TableCell>
              <TableCell>{formatCurrency(totals.centerSale)}</TableCell>
              <TableCell>{formatCurrency(totals.corporate)}</TableCell>
              <TableCell>{formatCurrency(totals.digital)}</TableCell>
              <TableCell>{formatCurrency(totals.referral)}</TableCell>
              <TableCell>{formatCurrency(totals.netSale)}</TableCell>
            </TableRow>
            <TableRow className="font-semibold bg-primary/60">
              <TableCell>This Month's Sale</TableCell>
              <TableCell>285</TableCell>
              <TableCell>{formatCurrency(82000)}</TableCell>
              <TableCell>{formatCurrency(28500)}</TableCell>
              <TableCell>{formatCurrency(16000)}</TableCell>
              <TableCell>{formatCurrency(9500)}</TableCell>
              <TableCell>{formatCurrency(9_360_0)}</TableCell>
            </TableRow>
          </TableFooter>
        </Table>
      </CardContent>
    </Card>
  );
};

export default RequestTable;
