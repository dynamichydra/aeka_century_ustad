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


const CpWiseSalesTable = () => {
 const cpWiseSales = [
  {
    id: 1,
    cpName: "MediCare Diagnostics",
    totalPatient: 62,
    totalSales: 18500,
  },
  { id: 2, cpName: "HealthPoint Labs", totalPatient: 54, totalSales: 16200 },
  { id: 3, cpName: "CityCare Clinic", totalPatient: 48, totalSales: 14000 },
  {
    id: 4,
    cpName: "LifeLine Diagnostics",
    totalPatient: 70,
    totalSales: 21000,
  },
  {
    id: 5,
    cpName: "Wellness Path Center",
    totalPatient: 40,
    totalSales: 12000,
  }
];
  const totalPatients = cpWiseSales.reduce((sum, d) => sum + d.totalPatient, 0);
  const totalSales = cpWiseSales.reduce((sum, d) => sum + d.totalSales, 0);

  const formatCurrency = (num: number) =>
    num.toLocaleString("en-IN", { style: "currency", currency: "INR" });
  return (
    <Card className="col-span-12 md:col-span-6">
      <CardHeader className="flex justify-between items-center">
        <CardTitle>CP Wise Sales</CardTitle>
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
              <TableHead>CP Name</TableHead>
              <TableHead>Total Patient</TableHead>
              <TableHead>Total Sales</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {cpWiseSales.map((row) => (
              <TableRow key={row.id}>
                <TableCell>{row.cpName}</TableCell>
                <TableCell>{row.totalPatient}</TableCell>
                <TableCell>{formatCurrency(row.totalSales)}</TableCell>
              </TableRow>
            ))}
          </TableBody>
          <TableFooter>
            <TableRow className="font-semibold bg-primary/25">
              <TableCell>Total</TableCell>
              <TableCell>{totalPatients}</TableCell>
              <TableCell>{formatCurrency(totalSales)}</TableCell>
            </TableRow>
          </TableFooter>
        </Table>
      </CardContent>
    </Card>
  );
};

export default CpWiseSalesTable;
