import { QueryClientProvider } from "@tanstack/react-query";
import { Toaster } from "react-hot-toast";
import { ThemeProvider } from "@/components/theme-provider";
import queryClient from "@/lib/queryClient";
import AppRoutes from "@/routes/AppRoutes";
function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider defaultTheme="light" storageKey="vite-ui-theme">
        <AppRoutes />
        <Toaster/>
      </ThemeProvider>
    </QueryClientProvider>
  );
}

export default App;
