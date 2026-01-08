import API from "@/lib/api";
import toast from "react-hot-toast";
import { type QueryOptions } from "@/lib/types";


export async function getData<T = any>(
  key: string,
  options?: QueryOptions
): Promise<{ message: T; count?: number } | null> {
  try {
    const response = await API.post("", {
      TYPE: key,
      TASK: "get",
      DATA: options ?? {},
    });

    const {
      data: { SUCCESS, MESSAGE, COUNT },
    } = response;

    if (SUCCESS) {
      return {
        message: MESSAGE as T,
        count: COUNT,
      };
    } else {
      toast.error(
        typeof MESSAGE === "string" ? MESSAGE : "Failed to fetch data"
      );
      return null;
    }
  } catch (error: any) {
    toast.error(error?.message || "Something went wrong");
    return null;
  }
}

export async function getCustomData<T = any>(
  key: string,
  options?: any
): Promise<{ message: T; count?: number } | null> {
  try {
    const response = await API.post("", {
      TYPE: key,
      TASK: "custom",
      DATA: options ?? {},
    });

    const {
      data: { SUCCESS, MESSAGE, COUNT },
    } = response;

    if (SUCCESS) {
     return {
       message: MESSAGE as T,
       count: COUNT,
     };
    } else {
      toast.error(
        typeof MESSAGE === "string" ? MESSAGE : "Failed to fetch data"
      );
      return null;
    }
  } catch (error: any) {
    toast.error(error?.message || "Something went wrong");
    return null;
  }
}


export async function setData<T = any>(
  key: string,
  payload: Partial<T>
): Promise<boolean> {
  try {
    const response = await API.post("", {
      TYPE: key,
      TASK: "set",
      DATA: payload,
    });

    const {
      data: { SUCCESS, MESSAGE },
    } = response;

    if (SUCCESS) {
      return MESSAGE;
    } else {
      toast.error(
        typeof MESSAGE === "string" ? MESSAGE : "Failed to update data"
      );
      return false;
    }
  } catch (error: any) {
    toast.error(error?.message || "Something went wrong");
    return false;
  }
}


export async function patchData<T = any>(
  key: string,
  payload: (Partial<T> & { ID_RESPONSE: string; BACKEND_ACTION: string })[]
): Promise<boolean> {
  try {
    const response = await API.post("", {
      TYPE: key,
      TASK: "patch",
      DATA: payload,
    });

    const {
      data: { SUCCESS, MESSAGE },
    } = response;

    if (SUCCESS) {
      return MESSAGE;
    } else {
      toast.error(
        typeof MESSAGE === "string" ? MESSAGE : "Failed to patch data"
      );
      return false;
    }
  } catch (error: any) {
    toast.error(error?.message || "Something went wrong");
    return false;
  }
}
