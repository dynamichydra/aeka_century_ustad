import z from "zod";

export const formSchema = z.object({
  // email: z.string().email({ message: "Invalid email address" }),
  email: z.string().nonempty('Email is requared'),
  password: z
    .string().nonempty('Password is requared')
    // .min(8, { message: "Password must be at least 8 characters long" })
    // .max(64, { message: "Password must be at most 64 characters long" }),
});
