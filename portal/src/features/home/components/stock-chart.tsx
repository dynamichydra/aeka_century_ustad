import { Bar, BarChart, CartesianGrid, XAxis } from "recharts";

import {
  Card,
  CardContent,
  CardDescription,
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
import { useGetCustomData, useGetData } from "@/lib/hooks";
import type { User } from "@/features/users/schema";
import type { StockReport } from "@/features/stock/types";
import { Loader2Icon } from "lucide-react";
import type { Branch } from "@/features/branche/types";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useEffect, useState } from "react";

export function ChartBarMultiple({ link, user }: { link?: string; user:User}) {
  const {data:branches, isLoading:branchIsLoading} = useGetData<Branch[]>('branch', {order:{by:'name', type:'ASC'}});
  const[branch,setBranch] = useState<string| null>(null);
   useEffect(() => {
     if (!branchIsLoading && branches?.message?.length && user.type !== "BAT") {
       setBranch(String(branches.message[0].id));
     }
   }, [branchIsLoading, branches, user.type]);

   const branchId = user.type === "BAT" ? user.branch[0] : branch;

   const shouldFetch = !!branchId;
   const {
     data: items,
     isLoading: isLoadingItem,
     isFetching,
   } = useGetCustomData<StockReport[]>(
     "stock",
     shouldFetch
       ? {
           type: "list",
           prod_id: null,
           branch_id: branchId,
         }
       : undefined,
     { keepPrevious: true, enabled: shouldFetch }
   );

  const chartConfig = {
    current_stock: {
      label: "Avalable Stock",
      color: "var(--chart-1)",
    },
    requested: {
      label: "Sales request",
      color: "var(--chart-2)",
    },
    transit: {
      label: "On production",
      color: "var(--chart-3)",
    },
  } satisfies ChartConfig;

  return (
    <Card className="col-span-12">
      <CardHeader className="flex justify-between items-center">
        <div>
          <CardTitle>Stock</CardTitle>
          <CardDescription>Branch Wise Stock</CardDescription>
        </div>
        <div className="flex justify-center items-center gap-3">
          { user.type !=="BAT" && <Select onValueChange={(val) => setBranch(val)}>
            <SelectTrigger className="rounded-xl text-xs">
              <SelectValue placeholder="Select a branch" />
            </SelectTrigger>
            <SelectContent>
              {!branchIsLoading &&
                branches?.message.map((b) => (
                  <SelectItem key={b.id} value={String(b.id)}>
                    {b.name}
                  </SelectItem>
                ))}
            </SelectContent>
          </Select>}
          {link && (
            <Link to={link}>
              <Button
                variant="outline"
                size="sm"
                className="text-xs rounded-xl"
              >
                View details
              </Button>
            </Link>
          )}
        </div>
      </CardHeader>
      {isLoadingItem || isFetching ? (
        <div className="flex justify-center items-center py-20 text-muted-foreground">
          <Loader2Icon className="animate-spin w-8 h-8 mr-2" />
        </div>
      ) : (
        <CardContent className="h-64 w-full">
          <ChartContainer config={chartConfig} className="h-full w-full">
            <BarChart accessibilityLayer data={items?.message}>
              <CartesianGrid vertical={false} />
              <XAxis
                dataKey="sku_number"
                tickLine={false}
                tickMargin={10}
                axisLine={false}
              />
              <ChartTooltip
                cursor={false}
                content={<ChartTooltipContent indicator="dashed" />}
              />
              <Bar
                dataKey="current_stock"
                fill="var(--color-current_stock)"
                radius={4}
              />
              <Bar
                dataKey="requested"
                fill="var(--color-requested)"
                radius={4}
              />
              <Bar dataKey="transit" fill="var(--color-transit)" radius={4} />
            </BarChart>
          </ChartContainer>
        </CardContent>
      )}
    </Card>
  );
}
