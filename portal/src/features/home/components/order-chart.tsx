import {
  ResponsiveContainer,
  LineChart,
  Line,
  CartesianGrid,
  XAxis,
  YAxis,
  Tooltip,
} from "recharts";

import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Link } from "react-router";
import { Button } from "@/components/ui/button";
import { useGetCustomData } from "@/lib/hooks";

const OrderChart = ({branch, type}:{branch:number, type:string}) => {
  const { data } = useGetCustomData<any[]>(
      "dashboard",
      {
        type: "order_chart",
        branch: branch,
        uType: type
      }
    );

    let chartData: { month: string; orders: number }[] = [];
    
    if(data && data.message && data.message.length >0){

      chartData = data.message.map(r => ({
        month: r.month,
        orders: Number(r.orders)
      }));
    }
  return (
    <Card className="col-span-12 md:col-span-6">
      <CardHeader className="flex justify-between items-center">
        <CardTitle>Orders Trend</CardTitle>
        <Link to={"/branch/order"}>
          <Button
            variant="outline"
            size="sm"
            className="mt-2 text-xs rounded-xl"
          >
            View details
          </Button>
        </Link>
      </CardHeader>
      <CardContent className="h-64">
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="month" />
            <YAxis />
            <Tooltip />
            <Line
              type="monotone"
              dataKey="orders"
              stroke="#4f46e5"
              strokeWidth={2}
              dot={{ r: 4 }}
            />
          </LineChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  );
}

export default OrderChart