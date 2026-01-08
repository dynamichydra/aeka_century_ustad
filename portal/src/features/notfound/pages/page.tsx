import { Button } from "@/components/ui/button";
import { ArrowLeft, Home } from "lucide-react";
import { useNavigate } from "react-router-dom";

export default function NotFound() {
  const navigate = useNavigate();

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-background text-center p-6">
          <h1 className="text-7xl font-extrabold text-primary">404</h1>
          <p className="text-muted-foreground text-lg mt-3">
            Oops! The page you’re looking for doesn’t exist.
          </p>
          <div className="flex gap-4 justify-center mt-12">
            <Button
              onClick={() => navigate(-1)}
              variant="outline"
              className="flex items-center gap-2"
            >
              <ArrowLeft className="w-4 h-4" /> Go Back
            </Button>
            <Button
              onClick={() => navigate("/")}
              className="flex items-center gap-2"
            >
              <Home className="w-4 h-4" /> Home
            </Button>
          </div>
    </div>
  );
}
