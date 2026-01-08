import React from "react";
import {
  flexRender,
  getCoreRowModel,
  getPaginationRowModel,
  useReactTable,
  getSortedRowModel,
  getFilteredRowModel,
} from "@tanstack/react-table";

import type {
  ColumnDef,
  SortingState,
  ColumnFiltersState,
  RowSelectionState,
} from "@tanstack/react-table";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

import Paginator from "./paginator";
import DM_CORE_CONFIG from "@/constant";
import { cn } from "@/lib/utils";

type DataTableProps<TData> = {
  columns: ColumnDef<TData, any>[];
  data: TData[];
  pageIndex: number;
  onPageChange: (pageIndex: number) => void;
  onRowClick?: (row: TData) => void;
  pageCount: number;
  fixedHeader?: boolean
  needPagination?:boolean
};

export function DataTable<TData>({
  columns,
  data,
  pageIndex,
  onPageChange,
  onRowClick,
  pageCount,
  fixedHeader = false,
  needPagination = true,
}: DataTableProps<TData>) {
  const [sorting, setSorting] = React.useState<SortingState>([]);
  const [columnFilters, setColumnFilters] = React.useState<ColumnFiltersState>(
    []
  );
  const [rowSelection, setRowSelection] = React.useState<RowSelectionState>({});

  const table = useReactTable<TData>({
    data,
    columns,
    manualPagination: true,
    pageCount,
    getCoreRowModel: getCoreRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
    onSortingChange: setSorting,
    getSortedRowModel: getSortedRowModel(),
    onColumnFiltersChange: setColumnFilters,
    getFilteredRowModel: getFilteredRowModel(),
    onRowSelectionChange: setRowSelection,
    state: {
      pagination: {
        pageIndex,
        pageSize: 10,
      },
      sorting,
      columnFilters,
      rowSelection,
    },
    onPaginationChange: (updater) => {
      const newState =
        typeof updater === "function"
          ? updater({ pageIndex, pageSize: DM_CORE_CONFIG.PAGESIZE })
          : updater;
      onPageChange(newState.pageIndex);
    },
    defaultColumn: { size: undefined },
  });

  return (
    <div>
      <div className="overflow-hidden rounded-md border ">
        <Table
          containerClass={cn(fixedHeader && "max-h-[500px] overflow-y-auto")}
        >
          <TableHeader
            className={cn(
              "bg-popover-foreground/10",
              fixedHeader && "sticky top-0 z-20 backdrop-blur-3xl"
            )}
          >
            {table.getHeaderGroups().map((headerGroup) => (
              <TableRow key={headerGroup.id}>
                {headerGroup.headers.map((header) => (
                  <TableHead key={header.id}>
                    {header.isPlaceholder
                      ? null
                      : flexRender(
                          header.column.columnDef.header,
                          header.getContext()
                        )}
                  </TableHead>
                ))}
              </TableRow>
            ))}
          </TableHeader>
          <TableBody>
            {table.getRowModel().rows?.length ? (
              table.getRowModel().rows.map((row) => (
                <TableRow
                  key={row.id}
                  onClick={() => onRowClick?.(row.original)}
                  data-state={row.getIsSelected() && "selected"}
                >
                  {row.getVisibleCells().map((cell) => (
                    <TableCell
                      key={cell.id}
                      style={{
                        maxWidth: cell.column.columnDef.size
                          ? cell.column.columnDef.size
                          : undefined,
                      }}
                    >
                      {flexRender(
                        cell.column.columnDef.cell,
                        cell.getContext()
                      )}
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell
                  colSpan={columns.length}
                  className="h-24 text-center"
                >
                  No results.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      { needPagination && <div className="flex items-center justify-end space-x-2 py-4">
        <div className="flex-1 text-sm text-muted-foreground">
          {table.getFilteredSelectedRowModel().rows.length
            ? `${table.getFilteredSelectedRowModel().rows.length} of `
            : null}
          {table.getFilteredRowModel().rows.length} row(s)
        </div>
        <div className="flex justify-center">
          <Paginator
            currentPage={table.getState().pagination.pageIndex + 1}
            totalPages={pageCount}
            onPageChange={(pageNumber: number) => onPageChange(pageNumber - 1)}
            showPreviousNext
          />
        </div>
      </div>}

    </div>
  );
}
