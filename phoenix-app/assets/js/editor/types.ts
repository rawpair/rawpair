// SPDX-License-Identifier: MPL-2.0

export type FileTreeItem = {
  id: string;
  name: string;
  children?: FileTreeItem[];
}