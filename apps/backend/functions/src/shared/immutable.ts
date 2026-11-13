export type DeepReadonly<T> = T extends
  string | number | boolean | bigint | symbol | null | undefined
  ? T
  : T extends (...args: never[]) => unknown
    ? T
    : T extends readonly (infer Item)[]
      ? readonly DeepReadonly<Item>[]
      : T extends object
        ? { readonly [Key in keyof T]: DeepReadonly<T[Key]> }
        : T;

export function deepFreeze<T>(value: T): DeepReadonly<T> {
  freezeRecursively(value, new WeakSet<object>());
  return value as DeepReadonly<T>;
}

function freezeRecursively(value: unknown, seen: WeakSet<object>): void {
  if (typeof value !== 'object' || value === null || seen.has(value)) return;
  seen.add(value);

  for (const child of Object.values(value)) freezeRecursively(child, seen);
  Object.freeze(value);
}
