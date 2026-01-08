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


const MarketingWiseSalesTable = () => {
  const marketingWiseSales = [
    {
      id: 1,
      marketingExec: "Rahul Verma",
      gross: 25000,
      discount: 3000,
      reversal: 500,
      net: 21500,
    },
    {
      id: 2,
      marketingExec: "Sneha Iyer",
      gross: 28000,
      discount: 2500,
      reversal: 800,
      net: 24700,
    },
    {
      id: 3,
      marketingExec: "Ankit Mehta",
      gross: 22000,
      discount: 2000,
      reversal: 400,
      net: 19600,
    },
    {
      id: 4,
      marketingExec: "Priya Sharma",
      gross: 30000,
      discount: 3500,
      reversal: 700,
      net: 25800,
    },
    {
      id: 5,
      marketingExec: "Amit Bansal",
      gross: 26000,
      discount: 2800,
      reversal: 600,
      net: 22600,
    },
  ];
  const totals = marketingWiseSales.reduce(
    (acc, curr) => {
      acc.gross += curr.gross;
      acc.discount += curr.discount;
      acc.reversal += curr.reversal;
      acc.net += curr.net;
      return acc;
    },
    { gross: 0, discount: 0, reversal: 0, net: 0 }
  );

  const formatCurrency = (num: number) =>
    num.toLocaleString("en-IN", { style: "currency", currency: "INR" });

  return (
    <Card className="col-span-12 md:col-span-6">
      <CardHeader className="flex justify-between items-center">
        <CardTitle>Marketing Wise Sales</CardTitle>
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
              <TableHead>Marketing Ex</TableHead>
              <TableHead>Gross</TableHead>
              <TableHead>Discount</TableHead>
              <TableHead>Reversal</TableHead>
              <TableHead>Net</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {marketingWiseSales.map((row) => (
              <TableRow
                key={row.id}
                className="hover:bg-muted/30 transition-colors"
              >
                <TableCell>{row.marketingExec}</TableCell>
                <TableCell>{formatCurrency(row.gross)}</TableCell>
                <TableCell>{formatCurrency(row.discount)}</TableCell>
                <TableCell>{formatCurrency(row.reversal)}</TableCell>
                <TableCell>{formatCurrency(row.net)}</TableCell>
              </TableRow>
            ))}
          </TableBody>
          <TableFooter>
            <TableRow className="font-semibold bg-primary/25">
              <TableCell>Total</TableCell>
              <TableCell>{formatCurrency(totals.gross)}</TableCell>
              <TableCell>{formatCurrency(totals.discount)}</TableCell>
              <TableCell>{formatCurrency(totals.reversal)}</TableCell>
              <TableCell>{formatCurrency(totals.net)}</TableCell>
            </TableRow>
          </TableFooter>
        </Table>
      </CardContent>
    </Card>
  );
};

export default MarketingWiseSalesTable;
