import React from "react";
import {
  PaginationEllipsis,
  PaginationItem,
  PaginationLink,
} from "@/components/data-table/pagination";

type GeneratePaginationLinksProps = {
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
};

/**
 * Generates pagination link components based on the current page and total pages.
 * Includes logic for showing ellipses for large page sets.
 */
export const generatePaginationLinks = ({
  currentPage,
  totalPages,
  onPageChange,
}: GeneratePaginationLinksProps): React.ReactNode[] => {
  const pages: React.ReactNode[] = [];

  if (totalPages <= 6) {
    // Show all pages if the count is small
    for (let i = 1; i <= totalPages; i++) {
      pages.push(
        <PaginationItem key={`page-${i}`}>
          <PaginationLink
            onClick={() => onPageChange(i)}
            isActive={i === currentPage}
          >
            {i}
          </PaginationLink>
        </PaginationItem>
      );
    }
  } else {
    // Show first two pages
    for (let i = 1; i <= 3; i++) {
      pages.push(
        <PaginationItem key={`page-${i}`}>
          <PaginationLink
            onClick={() => onPageChange(i)}
            isActive={i === currentPage}
          >
            {i}
          </PaginationLink>
        </PaginationItem>
      );
    }

    // Show ellipsis and current page (if it's in the middle)
    if (currentPage > 3 && currentPage < totalPages - 2) {
      pages.push(<PaginationEllipsis key="start-ellipsis" />);
      pages.push(
        <PaginationItem key={`page-${currentPage}`}>
          <PaginationLink onClick={() => onPageChange(currentPage)} isActive>
            {currentPage}
          </PaginationLink>
        </PaginationItem>
      );
      pages.push(<PaginationEllipsis key="end-ellipsis" />);
    } else {
      // Show middle ellipsis if needed
      pages.push(<PaginationEllipsis key="middle-ellipsis" />);
    }

    // Show last two pages
    for (let i = totalPages - 1; i <= totalPages; i++) {
      pages.push(
        <PaginationItem key={`page-${i}`}>
          <PaginationLink
            onClick={() => onPageChange(i)}
            isActive={i === currentPage}
          >
            {i}
          </PaginationLink>
        </PaginationItem>
      );
    }
  }

  return pages;
};
