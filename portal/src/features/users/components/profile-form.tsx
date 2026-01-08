import { useForm } from "react-hook-form";
import { z } from "zod";
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
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
} from "@/components/ui/select";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Textarea } from "@/components/ui/textarea";
import { UserSchema } from "../schema";
import { useNavigate } from "react-router";
import { useUser } from "@/hooks/use-user";
import { usePatchData, useSetData } from "@/lib/hooks";
import toast from "react-hot-toast";
import { LocationField } from "@/components/location";
import type { Branch } from "@/features/branche/types";

import { itemStatusOptions, UserTypeOptions } from "@/lib/types";
import { BranchMultiSelect } from "@/components/BranchMultiSelect";
import type { PatchPayload } from "../types";

type ProfileFormValues = z.infer<typeof UserSchema>;

export default function ProfileForm({
  initial,
  branch,
}: {
  initial?: ProfileFormValues;
  branch: Branch[];
}) {
  const navigate = useNavigate();

  const { user: createdUser } = useUser();

  const { patchData } = usePatchData("user_branch_access");
  let request_user_Id: number | undefined = initial?.id;

  const form = useForm<ProfileFormValues>({
    resolver: zodResolver(UserSchema),
    defaultValues: {
      ...initial,
      state: initial?.state?.toString() ?? "",
      city: initial?.city?.toString() ?? "",
      zip: initial?.zip?.toString() ?? "",
      status: initial?.status || "active",
      type: initial?.type || "Sales",

      branch: initial?.branch ?? [],
      created_by: initial?.created_by?.toString(),
      ziplabel: initial?.ziplabel ?? "",
    },
  });

  const userType = form.watch("type");

  const { setData } = useSetData<ProfileFormValues>("user");

  console.log(form.formState.errors);

  const onSubmit = (data: ProfileFormValues) => {

    setData(
      {
        ...data,
        id: initial?.id ?? undefined,
        created_by: createdUser?.id.toString(),
        branch: undefined,
      },
      {
        onSuccess: () => {
          if (!request_user_Id) {
            console.error("No request_id found in response");
            return;
          }
          console.log("requestId: ", request_user_Id, createdUser?.id);
          const patchPayload: PatchPayload = [];
          initial?.uba_id?.map((b) => {
            patchPayload.push({
              BACKEND_ACTION: "delete",
              ID_RESPONSE: `item_${b}`,
              id: b,
            });
          });
          data.branch.map((b, index) =>
            patchPayload.push({
              BACKEND_ACTION: "update",
              ID_RESPONSE: `item_${index + 1}`,
              user_id: request_user_Id,
              branch_id: b,
              created_by: createdUser?.id,
            })
          );   
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
    <div className="container mx-auto max-w-4xl">
      <Card>
        <CardHeader>
          <CardTitle className="text-2xl font-bold">Profile</CardTitle>
        </CardHeader>
        <CardContent>
          <Form {...form}>
            <form
              onSubmit={form.handleSubmit(onSubmit)}
              className="grid grid-cols-1 md:grid-cols-2 gap-6"
            >
              {/* Code */}
              <FormField
                control={form.control}
                name="code"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Code</FormLabel>
                    <FormControl>
                      <Input placeholder="User code" {...field} />
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
                      <Input placeholder="Full name" {...field} />
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
                        type="email"
                        placeholder="user@example.com"
                        {...field}
                        disabled
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
                        placeholder="+91 98765 43210"
                        {...field}
                        disabled
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              {/* Password */}
              {/* <FormField
                control={form.control}
                name="pwd"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Password</FormLabel>
                    <FormControl>
                      <Input
                        type="password"
                        placeholder="••••••••"
                        {...field}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              /> */}

              {/* Address */}
              <FormField
                control={form.control}
                name="address"
                render={({ field }) => (
                  <FormItem className="md:col-span-2">
                    <FormLabel>Address</FormLabel>
                    <FormControl>
                      <Textarea
                        placeholder="Street, locality, etc."
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
                defaultZipLable={initial?.ziplabel ?? ''}
              />

              {/* Status */}
              <FormField
                control={form.control}
                name="status"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Status</FormLabel>
                    <Select onValueChange={field.onChange} value={field.value}>
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

              {/* Type */}
              <FormField
                control={form.control}
                name="type"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>User Type</FormLabel>
                    <Select onValueChange={field.onChange} value={field.value}>
                      <FormControl>
                        <SelectTrigger className="w-full">
                          <SelectValue placeholder="Select type" />
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
              {/* <FormField
                control={form.control}
                name="branch"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Branch</FormLabel>
                    <FormControl>
                      <Input
                        placeholder="Branch name"
                        {...field}
                        value={field.value != null ? String(field.value) : ""}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              /> */}

              {/* Branch */}
              {/* {(userType === "Sales" || userType === "BAT") && (
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
              )} */}
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

              {/* Branch -- end*/}
              {/* Save Button */}
              <div className="md:col-span-2 flex justify-end">
                <Button type="submit">Save Changes</Button>
              </div>
            </form>
          </Form>
        </CardContent>
      </Card>
    </div>
  );
}
