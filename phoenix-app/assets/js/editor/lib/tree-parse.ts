// SPDX-License-Identifier: MPL-2.0

import { FileTreeItem } from "../types";

const sortChildren = (items: FileTreeItem[]) => {
  items.sort((a, b) => a.name.localeCompare(b.name));
  for (const item of items) {
    if (item.children) {
      sortChildren(item.children);
    }
  }
};

export const flatFileListToTreeItems = (paths: string[]): FileTreeItem[] => {
  const root: FileTreeItem = { id: '', name: '', children: [] };

  for (const path of paths) {
    const parts = path.split('/');
    let current = root;

    for (let i = 0; i < parts.length; i++) {
      const name = parts[i];
      const id = parts.slice(0, i + 1).join('/');

      if (!current.children) current.children = [];

      let existing = current.children.find(child => child.name === name);
      if (!existing) {
        existing = { id, name };
        current.children.push(existing);
      }

      current = existing;
    }
  }

  if (root.children) sortChildren(root.children);

  return root.children ?? [];
};