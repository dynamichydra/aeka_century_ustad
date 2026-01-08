import toast from "react-hot-toast";

export function handleError(
  error: unknown,
  defaultMessage = "Something went wrong"
) {
  if (typeof error === "string") {
    toast.error(error);
  } else if (error instanceof Error) {
    toast.error(error.message || defaultMessage);
  } else if (
    typeof error === "object" &&
    error !== null &&
    "message" in error
  ) {
    toast.error((error as any).message || defaultMessage);
  } else {
    toast.error(defaultMessage);
  }

  console.error("Caught Error:", error);
}
