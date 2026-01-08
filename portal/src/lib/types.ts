import { z } from "zod";

const makeZodEnum = <T extends string>(values: readonly T[]) => {
    return {
        values,
        schema: z.enum(values),
        type: undefined as unknown as T
    };
};

export type Condition = { key: string; value: string|number; operator: string }[];

export const ItemStatusDef = makeZodEnum([
  "active",
  "inactive",
] as const);
export type ItemStatus = typeof ItemStatusDef.type;
export const ItemStatusSchema = ItemStatusDef.schema;
export const itemStatusOptions = ItemStatusSchema.options;


export const ActionTypeDef = makeZodEnum([
  "approve", "delivery", "receive", "reject", "request", "damage", "manufacturing" 
] as const);
export type ActionType = typeof ActionTypeDef.type;
export const ActionTypeSchema = ActionTypeDef.schema;
export const actionTypeOptions = ActionTypeSchema.options;


export const UserTypeDef = makeZodEnum([
  "Admin", "Sales", "BAT", "PMG", "Commercial", "Factory"
] as const);
export type UserType = typeof UserTypeDef.type;
export const UserTypeSchema = UserTypeDef.schema;
export const UserTypeOptions = UserTypeSchema.options;

export type WhereOperator =
  | "is"
  | "isnot"
  | "higher"
  | "lower"
  | "higher-equal"
  | "lower-equal"
  | "in"
  | "notin"
  | "isnull"
  | "like";

export interface WhereCondition {
  key: string;
  operator: WhereOperator;
  value: string | number | boolean | Array<string | number>;
}

export type ReferenceType = "JOIN" | "LEFT JOIN" | "RIGHT JOIN";

export interface Reference {
  type: ReferenceType;
  obj: string;
  a: string;
  b: string;
}

export interface OrderOption {
  type: "ASC" | "DESC";
  by: string;
}

export type limit ={
  total: number;
  offset: number;
};

export interface QueryOptions {
  select?: string;
  where?: WhereCondition[];
  reference?: Reference[];
  limit?:limit
  order?: OrderOption;
  type?: string;
}

export type FilterOptions = {
  where: WhereCondition[];
  limit: {
    total: number;
    offset: number;
  };
};

export type FilterField = {
  key: string;
  label: string;
  type: "text" | "number" | "date" | "select";
  options?: { value: string; label: string }[];
};

export type FilterConfig = FilterField[];

export const productTypes = ["1mm" , "0.8mm", "Recon", "EGL", "Cubicle", "Sainik Laminates"];