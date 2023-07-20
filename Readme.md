# `lspize.nvim` -- Convert small functions into tiny LSPs in Neovim

This is a plugin designed to create simple LSPs running inside [Neovim](https://neovim.io). I wrote it to fill the gap in my configuration created by the archiving of [null-ls](https://github.com/jose-elias-alvarez/null-ls.nvim) (RIP). While [formatter.nvim](https://github.com/mhartington/formatter.nvim) is available for formatting tasks, [nvim-lint](https://github.com/mfussenegger/nvim-lint) is available for diagnostics, and [efm-langserver](https://github.com/mattn/efm-langserver) can supply diagnostics and formatting in an external server, there wasn't a solution for the hover and completion sources I had been using in null-ls.

`lspize.nvim` is a simple wrapper for uncomplicated functions that can provide a variety of LSP functionality to things that don't require full LSPs. See the examples below to see how it works!

## Example 1 -- Completion

Here is a server that returns completion items of available [LuaSnip](https://github.com/L3MON4D3/LuaSnip) snippets:

~~~lua
local Lsp = require("lspize")

local function get_documentation(snip, data)
	local header = (snip.name or "") .. " _ `[" .. data.filetype .. "]`\n"
	local docstring = { "", "```" .. vim.bo.filetype, snip:get_docstring(), "```" }
	local documentation = { header .. "---", (snip.dscr or ""), docstring }
	documentation = require("vim.lsp.util").convert_input_to_markdown_lines(documentation)
	return table.concat(documentation, "\n")
end

local handlers = {
	[Lsp.methods.COMPLETION] = function(params, done)
		local curline = vim.fn.line(".")
		local line, col = unpack(vim.fn.searchpos([[\k*]], "bcn"))
		if line ~= curline then
			done()
			return
		end
		local word_to_complete = vim.api.nvim_get_current_line():sub(col - 1, params.position.character)
		local filetypes = require("luasnip.util.util").get_snippet_filetypes()
		local items = {}

		for i = 1, #filetypes do
			local ft = filetypes[i]
			local ft_table = require("luasnip").get_snippets(ft)
			if ft_table then
				for j, snip in pairs(ft_table) do
					local data = {
						type = "luasnip",
						filetype = ft,
						ft_indx = j,
						snip_id = snip.id,
						show_condition = snip.show_condition,
					}
					if not snip.hidden then
						items[#items + 1] = {
							word = snip.trigger,
							label = snip.trigger,
							detail = snip.description,
							kind = vim.lsp.protocol.CompletionItemKind.Snippet,
							data = data,
							documentation = {
								value = get_documentation(snip, data),
								kind = vim.lsp.protocol.MarkupKind.Markdown,
							},
						}
					end
				end
			end
		end
		local line_to_cursor = require("luasnip.util.util").get_current_line_to_cursor()
		items = vim.tbl_filter(function(item)
			return vim.startswith(item.word, word_to_complete) and item.data.show_condition(line_to_cursor)
		end, items)
		done(nil, { isIncomplete = false, items = items })
	end,
}

Lsp.create(handlers, {
	name = "luasnip",
	on_attach = function()
		vim.bo.omnifunc = "v:lua.vim.lsp.omnifunc"
	end
})
~~~

Once you `require()` this file in your Neovim configuration, files will have an LSP that returns LuaSnip suggestions.
