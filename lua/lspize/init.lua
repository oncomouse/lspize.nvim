local methods = require("lspize.methods")
local Lsp = {}

local count = 1

function Lsp:new(handlers, opts)
	opts = opts or {
		filetypes = nil,
	}
	local capabilities = {}
	for method, _ in pairs(handlers) do
		if methods.request_name_to_capability[method] then
			for _, capability in pairs(methods.request_name_to_capability[method]) do
				capabilities[capability] = true
			end
		end
	end
	handlers.initialize = function(_, done)
		done(nil, { capabilities = capabilities })
	end
	setmetatable(handlers, {
		__index = function()
			return function(_, callback)
				callback()
			end
		end,
	})
	local autocmd_pattern
	if opts.filetype then
		autocmd_pattern = table.concat(type(opts.filetype) == "table" and opts.filetype or { opts.filetype }, ",")
	else
		autocmd_pattern = ""
	end
	local server = function(dispatchers)
		local closing = false
		return {
			request = vim.schedule_wrap(function(method, params, callback)
				handlers[method](params, callback)
			end),
			notify = function(...) end,
			is_closing = function()
				return closing
			end,
			terminate = function()
				if not closing then
					closing = true
					dispatchers.on_exit(0, 0)
				end
			end,
		}
	end
	vim.api.nvim_create_autocmd({ "FileType" }, {
		group = vim.api.nvim_create_augroup("lspize.nvim-" .. count, {}),
		pattern = autocmd_pattern,
		callback = function()
			local name = opts.name or ("lspize.nvim-" .. count)
			vim.lsp.start({
				name = name,
				cmd = server,
				flags = { debounce_text_changes = opts.debounce or 250 },
				on_attach = opts.on_attach
			})
			count = count + 1
		end,
	})
	return handlers
end

Lsp.methods = methods.lsp

return Lsp
