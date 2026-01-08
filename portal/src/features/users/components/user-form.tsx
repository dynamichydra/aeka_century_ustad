import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
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
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
} from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { UserSchema } from "../schema";
import { useNavigate } from "react-router";
import type { Branch } from "@/features/branche/types";
import { usePatchData, useSetData } from "@/lib/hooks";
import { itemStatusOptions, UserTypeOptions } from "@/lib/types";
import { hashStringSHA256 } from "@/lib/utils";
import { Loader2Icon } from "lucide-react";
import { useUser } from "@/hooks/use-user";
import toast from "react-hot-toast";

import { LocationField } from "@/components/location";
import { BranchMultiSelect } from "@/components/BranchMultiSelect";
import type { PatchPayload } from "../types";

type FormValues = z.infer<typeof UserSchema>;

export default function UserForm({
  user,
  mode,
  branch,
}: {
  user?: FormValues;
  mode: string;
  branch: Branch[];
}) {
  const navigate = useNavigate();

  const { user: createdUser } = useUser();
  


  const { patchData } = usePatchData("user_branch_access");
  let request_user_Id:number | undefined;

  

  const form = useForm<FormValues>({
    resolver: zodResolver(UserSchema),
    defaultValues: {
      code: user?.code ?? "",
      name: user?.name ?? "",
      email: user?.email ?? "",
      phone: user?.phone ?? "",
      pwd: user?.pwd ?? "",
      address: user?.address ?? "",
      state: user?.state?.toString() ?? "",
      city: user?.city?.toString() ?? "",
      zip: user?.zip?.toString() ?? "",
      status: user?.status ?? "active",
      type: user?.type ?? "Sales",
      branch: user?.branch ?? [],
      ziplabel: user?.ziplabel ?? "",
    },
  });

  const userType = form.watch("type");

  const { setData, isLoading } = useSetData<FormValues>("user");

  const onSubmit = async (values: z.infer<typeof UserSchema>) => {

    let finalPwd = values.pwd;
    if (!user?.id && values.pwd) {
      finalPwd = await hashStringSHA256(values.pwd);
    }
    setData(
      {
        ...values,
        id: user?.id ?? undefined,
        pwd: finalPwd,
        created_by: createdUser?.id.toString(),
        branch:undefined,
      },
      {
        onSuccess: (response: any) => {

          request_user_Id = response[0]?.id;

          if (mode=="edit") {
            request_user_Id = user?.id;
          }

          if (!request_user_Id) {
            console.error("No request_id found in response");
            return;
          }
          const patchPayload: PatchPayload = [];
          user?.uba_id?.map((b)=>{
            patchPayload.push({
              BACKEND_ACTION: "delete",
              ID_RESPONSE: `item_${b}`,
              id: b,
            });
          })
          values.branch.map((b, index) => (patchPayload.push({
            BACKEND_ACTION: "update",
            ID_RESPONSE: `item_${index + 1}`,
            user_id: request_user_Id,
            branch_id: b,
            created_by: createdUser?.id,
          })));          
          patchData(patchPayload, {
            onSuccess: () => {
              toast.success("Data updated successfully");
              form.reset();
              navigate(-1);
            },
          });
        },
      }
    );
  };

  return (
    <div className="max-w-3xl mx-auto p-4 md:p-6 bg-sidebar rounded-lg">
      <h1 className="text-center font-semibold text-xl">User</h1>
      <br />

      <Form {...form}>
        <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 md:gap-6">
            {/* Code */}
            <FormField
              control={form.control}
              name="code"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>User Code</FormLabel>
                  <FormControl>
                    <Input className="w-full" placeholder="U-001" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            {/* Name */}
            <FormField
              control={form.control}
              name="name"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Name</FormLabel>
                  <FormControl>
                    <Input
                      className="w-full"
                      placeholder="Full name"
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            {/* Email */}
            <FormField
              control={form.control}
              name="email"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Email</FormLabel>
                  <FormControl>
                    <Input
                      className="w-full"
                      type="email"
                      placeholder="user@example.com"
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            {/* Phone */}
            <FormField
              control={form.control}
              name="phone"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Phone</FormLabel>
                  <FormControl>
                    <Input
                      className="w-full"
                      placeholder="+91 9999999999"
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            {/* Password */}
            {mode == "create" && (
              <FormField
                control={form.control}
                name="pwd"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Password</FormLabel>
                    <FormControl>
                      <Input
                        className="w-full"
                        type="password"
                        placeholder="••••••••"
                        {...field}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            )}

            {/* type */}
            <FormField
              control={form.control}
              name="type"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>User type</FormLabel>
                  <Select
                    onValueChange={field.onChange}
                    value={field.value ?? "Sales"}
                  >
                    <FormControl>
                      <SelectTrigger className="w-full">
                        <SelectValue placeholder="Select Type" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {Object.entries(UserTypeOptions).map(([key, value]) => (
                        <SelectItem key={key} value={value}>
                          {value}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
            {/* Branch */}
            {/* {userType === "Sales" && (
              <FormField
                control={form.control}
                name="branch"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Branch</FormLabel>
                    <Select
                      value={field.value != null ? String(field.value) : ""}
                      onValueChange={(val) =>
                        field.onChange(val ? String(val) : null)
                      }
                    >
                      <FormControl>
                        <SelectTrigger className="w-full">
                          <SelectValue placeholder="Select branch" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        {branch?.map((b) => (
                          <SelectItem key={b.id} value={`${b.id}`}>
                            {b.name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />
            )} */}

            {/* ✅ Branch (multi-select if Sales) */}
            {(userType === "Sales" || userType === "BAT") && (
              <FormField
                control={form.control}
                name="branch"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>
                      {userType === "Sales"
                        ? "Branch"
                        : userType === "BAT"
                        ? "Branches"
                        : ""}
                    </FormLabel>
                    <FormControl>
                      {userType === "Sales" ? (
                        // 🔹 Single-select for Sales
                        <Select
                          value={field.value?.[0] ?? ""}
                          onValueChange={(val) => field.onChange([val])}
                        >
                          <SelectTrigger className="w-full">
                            <SelectValue placeholder="Select branch" />
                          </SelectTrigger>
                          <SelectContent>
                            {branch.map((b) => (
                              <SelectItem key={b.id} value={String(b.id)}>
                                {b.name}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      ) : (
                        <BranchMultiSelect
                          options={branch.map((b) => ({
                            label: b.name,
                            value: String(b.id),
                          }))}
                          value={field.value ?? []}
                          onChange={field.onChange}
                          placeholder="Select branches"
                        />
                      )}
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            )}

            {/* Address */}
            <FormField
              control={form.control}
              name="address"
              render={({ field }) => (
                <FormItem className="md:col-span-2">
                  <FormLabel>Address</FormLabel>
                  <FormControl>
                    <Textarea
                      className="w-full"
                      placeholder="Enter full address"
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <LocationField
              city="city"
              state="state"
              zip="zip"
              control={form.control}
              setValue={form.setValue}
              watch={form.watch}
              defaultZipLable = {user?.ziplabel ?? ''}
            />

            {/* Status */}
            <FormField
              control={form.control}
              name="status"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Status</FormLabel>
                  <Select
                    onValueChange={field.onChange}
                    value={field.value ?? "active"}
                  >
                    <FormControl>
                      <SelectTrigger className="w-full">
                        <SelectValue placeholder="Select status" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {itemStatusOptions.map((status) => (
                        <SelectItem key={status} value={status}>
                          {status.charAt(0).toUpperCase() + status.slice(1)}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
          </div>

          {/* Buttons */}
          <div className="flex flex-col md:flex-row justify-end gap-4 mt-4">
            <Button
              type="button"
              variant="outline"
              onClick={() => navigate(-1)}
              className="w-full md:w-auto"
            >
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
          </div>
        </form>
      </Form>
    </div>
  );
}
