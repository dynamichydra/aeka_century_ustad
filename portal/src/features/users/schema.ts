import { z } from "zod";
import { ItemStatusSchema, UserTypeSchema } from "@/lib/types";

export const UserSchema = z.object({
  id: z.number().optional(),

  code: z.string().min(1, "User code is required"),
  name: z.string().min(1, "Name is required"),
  email: z.string().email("Invalid email address"),
  phone: z.string().min(1, "Phone is required"),
  pwd: z.string().min(1, "Password is required"),
  address: z.string().optional(),
  state: z.string().min(1, "State is required"),
  city: z.string().min(1, "City is required"),
  zip: z
    .string()
    .min(1, "City is required")
    .transform((val) => val ?? null),
  created_by: z.string().optional(),
  status: ItemStatusSchema,
  type: UserTypeSchema,
  ziplabel: z.string().optional()
});
export type User = z.infer<typeof UserSchema>;
export const UserListSchema = z.array(UserSchema);

export const restPasswordSchema = z
  .object({
    newPwd: z.string().nonempty("New password is required"),
    cnfmNewPwd: z.string().nonempty("Confirm password is required"),
  })
  .refine((data) => data.newPwd === data.cnfmNewPwd, {
    message: "New password and confirm password do not match",
    path: ["cnfmNewPwd"],
  });

export type PasswordFormValues = z.infer<typeof restPasswordSchema>;