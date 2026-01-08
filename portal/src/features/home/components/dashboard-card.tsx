import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { TrendingUp } from "lucide-react";
import { Link } from "react-router";

export interface DashboardCardProps {
  title: string;
  value: string | number;
  change?: string;
  icon?: React.ElementType;
  iconColor?: string;
  link?: string;
  bgColor?: string;
}

export function DashboardCard({
  title,
  value,
  change,
  icon: Icon,
  link,
  bgColor,
  iconColor = "text-blue-500",
}: DashboardCardProps) {
  return (
    <Card className="transition hover:shadow-lg hover:-translate-y-0.5 col-span-12 md:col-span-6 lg:col-span-3">
      <CardHeader className="flex flex-row items-center justify-between pb-2 space-y-0">
        <CardTitle className="text-lg font-medium">{title}</CardTitle>
        {Icon && (
          <div
            className={`${bgColor} p-2 rounded-full flex items-center justify-center`}
          >
            <Icon className={`w-6 h-6 ${iconColor}`} />
          </div>
        )}
      </CardHeader>
      <CardContent className="flex justify-between items-start">
        <div>
          <div className="text-2xl font-bold">{value}</div>
          {change && (
            <p className="text-xs text-muted-foreground flex items-center gap-1">
              <TrendingUp className="h-3 w-3 text-green-500" />
              {change} from last month
            </p>
          )}
        </div>
        {link && (
          <Link to={link}>
            <Button
              variant="outline"
              size="sm"
              className="mt-2 text-xs rounded-xl"
            >
              View details
            </Button>
          </Link>
        )}
      </CardContent>
    </Card>
  );
}
