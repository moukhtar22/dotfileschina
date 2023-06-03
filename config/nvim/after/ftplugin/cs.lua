set = vim.bo
set.shiftwidth = 4
set.softtabstop = 4
set.expandtab = true

local util = require("lspconfig").util
local root_dir = function(file, _)
  if file:sub(-#".csx") == ".csx" then
    return util.path.dirname(file)
  end
  return util.root_pattern "*.sln"(file) or util.root_pattern "*.csproj"(file)
end

local pid = vim.fn.getpid()

-- local csharp_ls = {
--   name = "csharp_ls",
--   cmd = { "csharp-ls" },
--   -- root_dir = vim.fs.dirname(vim.fs.find({'Prueba.sln', 'Prueba.csproj'}, { upward = true })[1]),
--   init_options = { AutomaticWorkspaceInit = true },
--   handlers = {
--     ["textDocument/definition"] = require("csharpls_extended").handler,
--   },
--   root_dir = root_dir(vim.fn.expand "%"),
-- }
-- require("config.lsp").setup(csharp_ls)

local function on_attach(client, bufnr)
  local caps = client.server_capabilities
  caps.semanticTokensProvider = {
    full = vim.empty_dict(),
    legend = {
      tokenModifiers = { "static_symbol" },
      tokenTypes = {
        "comment",
        "excluded_code",
        "identifier",
        "keyword",
        "keyword_control",
        "number",
        "operator",
        "operator_overloaded",
        "preprocessor_keyword",
        "string",
        "whitespace",
        "text",
        "static_symbol",
        "preprocessor_text",
        "punctuation",
        "string_verbatim",
        "string_escape_character",
        "class_name",
        "delegate_name",
        "enum_name",
        "interface_name",
        "module_name",
        "struct_name",
        "type_parameter_name",
        "field_name",
        "enum_member_name",
        "constant_name",
        "local_name",
        "parameter_name",
        "method_name",
        "extension_method_name",
        "property_name",
        "event_name",
        "namespace_name",
        "label_name",
        "xml_doc_comment_attribute_name",
        "xml_doc_comment_attribute_quotes",
        "xml_doc_comment_attribute_value",
        "xml_doc_comment_cdata_section",
        "xml_doc_comment_comment",
        "xml_doc_comment_delimiter",
        "xml_doc_comment_entity_reference",
        "xml_doc_comment_name",
        "xml_doc_comment_processing_instruction",
        "xml_doc_comment_text",
        "xml_literal_attribute_name",
        "xml_literal_attribute_quotes",
        "xml_literal_attribute_value",
        "xml_literal_cdata_section",
        "xml_literal_comment",
        "xml_literal_delimiter",
        "xml_literal_embedded_expression",
        "xml_literal_entity_reference",
        "xml_literal_name",
        "xml_literal_processing_instruction",
        "xml_literal_text",
        "regex_comment",
        "regex_character_class",
        "regex_anchor",
        "regex_quantifier",
        "regex_grouping",
        "regex_alternation",
        "regex_text",
        "regex_self_escaped_character",
        "regex_other_escape",
      },
    },
    range = true,
  }
end

local omnisharp = {
  handlers = {
    ["textDocument/definition"] = require("omnisharp_extended").handler,
  },
  -- cmd = { "dotnet", "/usr/lib/omnisharp-roslyn/OmniSharp.dll", "--languageserver", "--hostPID", tostring(pid) },
  cmd = { "/usr/bin/omnisharp", "--languageserver", "--hostPID", tostring(pid) },
  enable_editorconfig_support = true,
  enable_ms_build_load_projects_on_demand = false,
  enable_roslyn_analyzers = true,
  organize_imports_on_format = true,
  enable_import_completion = true,
  sdk_include_prereleases = false,
  analyze_open_documents_only = true,
  root_dir = root_dir(vim.fn.expand "%"),
}
require("config.lsp").setup(omnisharp, on_attach)
