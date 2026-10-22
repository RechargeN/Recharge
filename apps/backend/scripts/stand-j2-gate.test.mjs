import assert from "node:assert/strict";
import test from "node:test";
import { main } from "./stand-j2-gate.mjs";
function harness(digests = ["same", "same", "same"]) {
  const calls = [];
  let seeds = 0;
  return {
    calls,
    hooks: {
      run: (script, args) => {
        calls.push(args.join(" "));
        if (args.join(" ") === "seed") return "seeded base";
        if (args.join(" ") === "route seed")
          return (++seeds === 3 ? "reused" : "seeded") + " route=id";
        return "";
      },
      exec: () => ({
        status: 1,
        output: "interrupted: stand route seed interrupted after distribute",
      }),
      digest: () => digests.shift(),
      flutter: (files, defines) =>
        calls.push([...files, ...(defines ?? [])].join(" ")),
    },
  };
}
void test("no reset without explicit --yes", async () => {
  await assert.rejects(() => main([]), /Usage:/);
});
void test("clean/resumed/repeated parity runs both actual mobile gate commands and cleans up", async () => {
  const h = harness();
  await main(["--yes"], h.hooks);
  assert.ok(
    h.calls.some(
      (s) =>
        s.includes("route_publication_ui_stand_test.dart") &&
        s.includes("RECHARGE_TEST_ROUTE_PUBLICATION=true"),
    ),
  );
  assert.deepEqual(h.calls.slice(-2), ["stop", "reset --yes"]);
});
void test("digest mismatch fails but still stops and cleans its stand", async () => {
  const h = harness(["clean", "wrong"]);
  await assert.rejects(() => main(["--yes"], h.hooks), /resumed/);
  assert.deepEqual(h.calls.slice(-2), ["stop", "reset --yes"]);
  assert.ok(
    !h.calls.some((s) => s.includes("route_publication_ui_stand_test.dart")),
  );
});
