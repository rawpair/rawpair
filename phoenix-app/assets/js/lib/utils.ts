import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function getCSRFToken() {
  return document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
}
