import { useQuery, useMutation, useQueryClient, keepPreviousData } from "@tanstack/react-query";
import { setData, getData, patchData, getCustomData } from "./commonApi";
import toast from "react-hot-toast";
import type { QueryOptions } from "./types";
import API from "./api";

type ExtraQueryOptions = {
  enabled?: boolean;
  keepPrevious?: boolean; 
};

export function useGetData<T = any>(
  key: string,
  options?: QueryOptions,
  queryOptions?: ExtraQueryOptions
) {
  return useQuery<{ message: T; count?: number } | null>({
    queryKey: [key, options],
    queryFn: () => getData<T>(key, options),
    enabled: queryOptions?.enabled ?? true,
    staleTime: 0,
    gcTime: 0,
    refetchOnWindowFocus: false,
    placeholderData: queryOptions?.keepPrevious ? keepPreviousData : undefined,
  });
}

export function useGetCustomData<T = any>(
  key: string,
  options?: any,
  queryOptions?: ExtraQueryOptions
) {
  return useQuery<{ message: T; count?: number } | null>({
    queryKey: [key, options],
    queryFn: () => getCustomData<T>(key, options),
    enabled: queryOptions?.enabled ?? true,
    staleTime: 0,
    gcTime: 0,
    refetchOnWindowFocus: false,
    placeholderData: queryOptions?.keepPrevious ? keepPreviousData : undefined,
  });
}

export function useSetData<T = any>(key: string) {
  const queryClient = useQueryClient();

  const { mutate, data, isPending , isError ,isSuccess ,error} = useMutation({
    mutationFn: (input: Partial<T>) => setData<T>(key, input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [key] });
    },
    onError: () => toast.error("Update failed ❌"),
  });

  return {
    setData: mutate,
    data,
    isLoading: isPending,
    isError,
    error,
    isSuccess:isSuccess,
  };
}

export function useSendData<T = any>(
  key: string,
) {
  const { mutate, data, isPending, isError, isSuccess, error } = useMutation({
    mutationFn: (input: Partial<T>) => getCustomData<T>(key, input),
    onError: () => toast.error("Message send failed ❌"),
  });

  return {
    sendMessage: mutate,
    data,
    isLoading: isPending,
    isError,
    error,
    isSuccess: isSuccess,
  };
}

export function usePatchData<T = any>(key: string) {
  const queryClient = useQueryClient();

  const { mutate, data, isPending, isError, error, isSuccess } = useMutation({
    mutationFn: (
      inputData: (Partial<T> & {
        ID_RESPONSE: string;
        BACKEND_ACTION: string;
      })[]
    ) => patchData<T>(key, inputData),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [key] });
    },
    onError: () => {
      toast.error("Patch failed ❌");
    },
  });

  return {
    patchData: mutate,
    data,
    isLoading: isPending,
    isError,
    error,
    isSuccess,
  };
}

export type AutocompleteOption = {
  value: string;
  label: string;
  [key: string]: any; 
};

export async function fetchData<T>(
  type: string,
  payload: Record<string, unknown>,
  mapFn: (item: any) => T
): Promise<T[]> {
  try {
    const response = await API.post("", {
      TYPE: type,
      TASK: "get",
      DATA: payload,
    });

    const {
      data: { SUCCESS, MESSAGE },
    } = response;

    if (!SUCCESS) {
      throw new Error("Failed to fetch " + type);
    }

    return MESSAGE.map(mapFn);
  } catch (error) {
    console.error(`Error fetching ${type}:`, error);
    return [];
  }
}

export function toBase64(str:string) {
  if (!str) return "";
  return btoa(unescape(encodeURIComponent(str)));
}

export function fromBase64(base64:string) {
  if (!base64) return "";
  return decodeURIComponent(escape(atob(base64)));
}