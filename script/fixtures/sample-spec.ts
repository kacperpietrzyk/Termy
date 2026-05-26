import { filepaths } from "@fig/autocomplete-generators";
const spec: Fig.Spec = {
  name: "sample",
  subcommands: [
    { name: ["rm", "remove"], options: [{ name: "-f" }] },
    { name: "remote", subcommands: [{ name: "add", args: { name: "url" } }] },
  ],
  options: [
    { name: ["-m", "--message"], args: { name: "msg" } },
    { name: "--amend" },
    { name: "-C", args: { name: "path", generators: filepaths } },
  ],
  args: { name: "pathspec" },
};
export default spec;
