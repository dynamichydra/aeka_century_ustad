import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import {
  Form,
  FormField,
  FormItem,
  FormLabel,
  FormControl,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";

import { useUser } from "@/hooks/use-user";
import { hashStringSHA256 } from "@/lib/utils";
import toast from "react-hot-toast";
import { useSetData } from "@/lib/hooks";
import type { User } from "../types";
import { LogOut } from "@/features/auth/api";
import { restPasswordSchema, type PasswordFormValues } from "../schema";
import { Loader2Icon } from "lucide-react";

export default function ResetPassword() {
  const { user } = useUser();
  const { setData, isLoading } = useSetData<User>("user");

  const form = useForm<PasswordFormValues>({
    resolver: zodResolver(restPasswordSchema),
    defaultValues: {
      newPwd: "",
      cnfmNewPwd: "",
    },
  });

  const onSubmit = async (data: PasswordFormValues) => {
    const newpasshashed = await hashStringSHA256(data.newPwd);
    setData(
      {
        id: user?.id ?? undefined,
        pwd: newpasshashed,
      },
      {
        onSuccess: () => {
          toast.success("Password updated successfully");
          form.reset();
          LogOut();
        },
      }
    );
  };

  return (
    <div className="container mx-auto max-w-4xl">
      <Card>
        <CardHeader>
          <CardTitle className="text-2xl font-bold">Reset Password</CardTitle>
        </CardHeader>
        <CardContent>
          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)}>
              <div className="grid gap-6">
                <FormField
                  control={form.control}
                  name="newPwd"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>New Password</FormLabel>
                      <FormControl>
                        <Input
                          type="password"
                          placeholder="New Password"
                          {...field}
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                <FormField
                  control={form.control}
                  name="cnfmNewPwd"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Confirm New Password</FormLabel>
                      <FormControl>
                        <Input
                          type="password"
                          placeholder="Confirm New Password"
                          {...field}
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>
              <div className="md:col-span-2 flex justify-end mt-4">
                <Button
                  type="submit"
                  className="w-full md:w-auto"
                  disabled={isLoading}
                >
                  {isLoading && <Loader2Icon className="animate-spin" />}
                  Reset Password
                </Button>
              </div>
            </form>
          </Form>
        </CardContent>
      </Card>
    </div>
  );
}
