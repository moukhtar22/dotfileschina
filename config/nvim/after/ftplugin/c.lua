local ccls = {
  name = "ccls",
  cmd = { "ccls" },
  single_file_support = true,
}
require("config.lsp").setup(ccls)
