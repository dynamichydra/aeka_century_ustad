import { cn, hashStringSHA256 } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { formSchema } from "@/features/auth/schema";
import { useLogin } from "../hooks";
import { AlertCircleIcon, Eye, EyeOff, LoaderCircle } from "lucide-react";
import { useNavigate } from "react-router";
import { Alert, AlertTitle } from "@/components/ui/alert";
import { useState } from "react";
import { InputGroup, InputGroupAddon, InputGroupInput } from "@/components/ui/input-group";

export function LoginForm({
  className,
  ...props
}: React.ComponentProps<"div">) {
  const [showPassword, setShowPassword] = useState(false);
  const form = useForm<z.infer<typeof formSchema>>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      email: "",
      password: "",
    },
  });
  const {login, isLoading, isError, error } = useLogin();
  const navigate = useNavigate();

  async function onSubmit(values: z.infer<typeof formSchema>) {
    const hashPassword = await hashStringSHA256(values.password);
    login(
      { email: values.email.trim(), password: hashPassword },
      {
        onSuccess: (res) => {
          if (res?.type == 'Sales') {
            navigate("/salesrequest", { replace: true });
          }else{
            navigate("/", { replace: true });
          }
        },
        onError: () => {
         form.reset();
        },
      }
    );
  }

  return (
    <div className={cn("flex flex-col gap-6", className)} {...props}>
      <Card>
        <CardHeader className="text-center">
          <CardTitle>Login to your account</CardTitle>
          <CardDescription className="flex flex-col gap-2">
            <span>
              Enter your E-mail / Phone No below to login to your account
            </span>
            {isError && (
              <Alert variant="destructive" className="bg-destructive/20">
                <AlertCircleIcon />
                <AlertTitle>{error?.message}</AlertTitle>
              </Alert>
            )}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-8">
              <FormField
                control={form.control}
                name="email"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>E-mail / Phone No.</FormLabel>
                    <FormControl>
                      <Input
                        placeholder="Enter E-mail / Phone No."
                        {...field}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={form.control}
                name="password"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Password</FormLabel>
                    <FormControl>
                      <InputGroup>
                        <InputGroupInput
                          placeholder="Enter Password"
                          {...field}
                          type={showPassword ? "text" : "password"}
                        />
                        <InputGroupAddon
                          align="inline-end"
                          className="cursor-pointer"
                          onClick={() => setShowPassword((prev) => !prev)}
                        >
                          {showPassword ? (
                            <EyeOff className="size-5" />
                          ) : (
                            <Eye className="size-5" />
                          )}
                        </InputGroupAddon>
                      </InputGroup>
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <Button type="submit" className="w-full" disabled={isLoading}>
                {isLoading ? (
                  <LoaderCircle className="animate-spin" />
                ) : (
                  "Submit"
                )}
              </Button>
            </form>
          </Form>
        </CardContent>
      </Card>
    </div>
  );
}
