import { Bar, BarChart, CartesianGrid, XAxis } from "recharts";

import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  type ChartConfig,
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
} from "@/components/ui/chart";
import { Link } from "react-router";
import { Button } from "@/components/ui/button";

export function ChartBarMultiple() {
  const dailySales = [
    { date: "2025-10-02", amount: 1800 },
    { date: "2025-10-03", amount: 2200 },
    { date: "2025-10-04", amount: 2500 },
    { date: "2025-10-05", amount: 2000 },
    { date: "2025-10-06", amount: 2700 },
    { date: "2025-10-07", amount: 3000 },
    { date: "2025-10-08", amount: 3200 },
    { date: "2025-10-09", amount: 3500 },
    { date: "2025-10-10", amount: 3300 },
    { date: "2025-10-11", amount: 3600 },
    { date: "2025-10-12", amount: 3800 },
    { date: "2025-10-13", amount: 4000 },
    { date: "2025-10-14", amount: 4200 },
    { date: "2025-10-15", amount: 2000 },
    { date: "2025-10-16", amount: 2500 },
    { date: "2025-10-17", amount: 3000 },
    { date: "2025-10-18", amount: 4000 },
    { date: "2025-10-19", amount: 5000 },
    { date: "2025-10-20", amount: 3500 },
    { date: "2025-10-21", amount: 4500 },
  ];

  const chartConfig = {
    amount: {
      label: "Amount",
      color: "var(--chart-2)",
    },
  } satisfies ChartConfig;

  return (
    <Card className="col-span-12">
      <CardHeader className="flex justify-between items-center">
        <div>
          <CardTitle>Daily Sales Chart</CardTitle>
        </div>
        <div className="flex justify-center items-center gap-3">
          <Link to="#">
            <Button variant="outline" size="sm" className="text-xs rounded-xl">
              View details
            </Button>
          </Link>
        </div>
      </CardHeader>
      <CardContent className="h-64 w-full">
        <ChartContainer config={chartConfig} className="h-full w-full">
          <BarChart accessibilityLayer data={dailySales}>
            <CartesianGrid vertical={true} />
            <XAxis
              dataKey="date"
              tickLine={false}
              tickMargin={10}
              axisLine={false}
            />
            <ChartTooltip
              cursor={true}
              content={<ChartTooltipContent indicator="dashed" />}
            />
            <Bar dataKey="amount" fill="var(--color-amount)" radius={3} />
          </BarChart>
        </ChartContainer>
      </CardContent>
    </Card>
  );
}
