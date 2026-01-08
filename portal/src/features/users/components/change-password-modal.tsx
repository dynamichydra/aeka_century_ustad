import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";

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
import type { User } from "../types";
import { useSetData } from "@/lib/hooks";
import toast from "react-hot-toast";
import { hashStringSHA256 } from "@/lib/utils";
import { restPasswordSchema, type PasswordFormValues } from "../schema";
import { Loader2Icon } from "lucide-react";

interface ChangePasswordModalProps {
  open: boolean;
  onClose: () => void;
  user: User | null;
}

export const ChangePasswordModal = ({
  open,
  onClose,
  user,
}: ChangePasswordModalProps) => {
  const { setData, isLoading } = useSetData<User>("user");

  const form = useForm<PasswordFormValues>({
    resolver: zodResolver(restPasswordSchema),
    defaultValues: {
      newPwd: "",
      cnfmNewPwd: "",
    },
  });

  const handleSubmit = async (data: PasswordFormValues) => {
    const hashed = await hashStringSHA256(data.newPwd);
    setData(
      {
        id: user?.id ?? undefined,
        pwd: hashed,
      },
      {
        onSuccess: () => toast.success("Password changed successfully"),
      }
    );
    onClose();
  };

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Change Password for {user?.name}</DialogTitle>
        </DialogHeader>

        <Form {...form}>
          <form
            onSubmit={form.handleSubmit(handleSubmit)}
            className="space-y-4"
          >
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
                      placeholder="Confirm Password"
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <DialogFooter className="pt-4">
              <Button type="button" variant="outline" onClick={onClose}>
                Cancel
              </Button>
              <Button
                type="submit"
                className="w-full md:w-auto"
                disabled={isLoading}
              >
                {isLoading && <Loader2Icon className="animate-spin" />}
                Save
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
};
