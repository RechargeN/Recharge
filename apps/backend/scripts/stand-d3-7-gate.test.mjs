import assert from "node:assert/strict";
import test from "node:test";
import { main } from "./stand-d3-7-gate.mjs";
function harness(digests = ["same", "same", "same"]) {
  const calls = [];
  let seeds = 0;
  return {
    calls,
    hooks: {
      run: (script, args) => {
        calls.push(args.join(" "));
        if (args.join(" ") === "seed") return "seeded base";
        if (args.join(" ") === "find-people seed")
          return (++seeds === 3 ? "reused" : "seeded") + " find-people=id";
        return "";
      },
      exec: () => ({
        status: 1,
        output: "interrupted: stand find-people seed interrupted after consent",
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
    h.calls.some((s) => s.includes("find_people_publication_stand_test.dart")),
  );
  assert.ok(
    h.calls.some(
      (s) =>
        s.includes("find_people_publication_ui_stand_test.dart") &&
        s.includes("RECHARGE_TEST_FIND_PEOPLE_PUBLICATION=true"),
    ),
  );
  assert.deepEqual(h.calls.slice(-2), ["stop", "reset --yes"]);
});
void test("digest mismatch fails but still stops and cleans its stand", async () => {
  const h = harness(["clean", "wrong"]);
  await assert.rejects(() => main(["--yes"], h.hooks), /resumed/);
  assert.deepEqual(h.calls.slice(-2), ["stop", "reset --yes"]);
  assert.ok(
    !h.calls.some((s) => s.includes("find_people_publication_stand_test.dart")),
  );
});
