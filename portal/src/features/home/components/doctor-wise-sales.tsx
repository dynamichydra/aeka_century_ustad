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


const DoctorWiseSalesTable = () => {
 const doctorWiseSales = [
  { id: 1, doctorName: "Dr. A. Sharma", totalPatient: 45, totalSales: 12500 },
  { id: 2, doctorName: "Dr. R. Patel", totalPatient: 38, totalSales: 11000 },
  { id: 3, doctorName: "Dr. M. Khan", totalPatient: 52, totalSales: 15000 },
  { id: 4, doctorName: "Dr. P. Gupta", totalPatient: 28, totalSales: 8200 },
  { id: 5, doctorName: "Dr. L. Nair", totalPatient: 33, totalSales: 9700 },
];


  const totalPatients = doctorWiseSales.reduce(
    (sum, d) => sum + d.totalPatient,
    0
  );
  const totalSales = doctorWiseSales.reduce((sum, d) => sum + d.totalSales, 0);

  const formatCurrency = (num: number) =>
    num.toLocaleString("en-IN", { style: "currency", currency: "INR" });
  return (
    <Card className="col-span-12 md:col-span-6">
      <CardHeader className="flex justify-between items-center">
        <CardTitle>Doctor Wise Sales</CardTitle>
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
              <TableHead>Doctor Name</TableHead>
              <TableHead>Total Patient</TableHead>
              <TableHead>Total Sales</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {doctorWiseSales.map((request) => (
              <TableRow key={request.id}>
                <TableCell>{request.doctorName}</TableCell>
                <TableCell>{request.totalPatient}</TableCell>
                <TableCell>{request.totalSales}</TableCell>
              </TableRow>
            ))}
          </TableBody>
          <TableFooter className="bg-primary/25">
            <TableRow className="font-semibold bg-muted/40">
              <TableCell>Today's Total</TableCell>
              <TableCell>{totalPatients}</TableCell>
              <TableCell>{formatCurrency(totalSales)}</TableCell>
            </TableRow>
          </TableFooter>
        </Table>
      </CardContent>
    </Card>
  );
};

export default DoctorWiseSalesTable;
