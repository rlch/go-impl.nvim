local config = require("go-impl.config")
local M = {}

function M.env()
	if M.env_initiated then
		return
	end
	M.env_initiated = true
	M.lsp = require("snacks.picker.source.lsp")

	setmetatable(M, {
		__index = function(_, k)
			return M.lsp[k]
		end,
	})
end

function M.is_loaded()
	local is_loaded = pcall(require, "snacks")
	if is_loaded then
		M.env()
	end
	return is_loaded
end

-- from snacks
function M.results_to_items(client, results, opts)
	opts = opts or {}
	local items = {} ---@type snacks.picker.finder.Item[]
	local last = {} ---@type table<snacks.picker.finder.Item, snacks.picker.finder.Item>

	---@param result lsp.ResultItem
	---@param parent snacks.picker.finder.Item
	local function add(result, parent)
		---@type snacks.picker.finder.Item
		local item = {
			kind = M.symbol_kind(result.kind),
			parent = parent,
			detail = result.detail,
			name = result.name,
			text = "",
			---@diagnostic disable-next-line: undefined-field
			package = result.containerName, -- MODIFIED: add gopls package info
		}
		local uri = result.location and result.location.uri or result.uri or opts.default_uri
		local loc = result.location or { range = result.selectionRange or result.range, uri = uri }
		loc.uri = loc.uri or uri
		M.add_loc(item, loc, client)
		local text = table.concat({ M.symbol_kind(result.kind), result.name }, " ")
		if opts.text_with_file and item.file then
			text = text .. " " .. item.file
		end
		item.text = text

		if not opts.filter or opts.filter(result) then
			items[#items + 1] = item
			last[parent] = item
			parent = item
		end

		for _, child in ipairs(result.children or {}) do
			add(child, parent)
		end
		result.children = nil
	end

	local root = { text = "" } ---@type snacks.picker.finder.Item
	---@type snacks.picker.finder.Item
	for _, result in ipairs(results) do
		add(result, root)
	end
	for _, item in pairs(last) do
		item.last = true
	end

	return items
end

-- from snacks
function M.symbols(opts, ctx)
	local buf = ctx.filter.current_buf
	-- For unloaded buffers, load the buffer and
	-- refresh the picker on every LspAttach event
	-- for 10 seconds. Also defer to ensure the file is loaded by the LSP.
	if not vim.api.nvim_buf_is_loaded(buf) then
		local id = vim.api.nvim_create_autocmd("LspAttach", {
			buffer = buf,
			callback = vim.schedule_wrap(function()
				if ctx.picker:count() > 0 then
					return true
				end
				ctx.picker:find()
				vim.defer_fn(function()
					if ctx.picker:count() == 0 then
						ctx.picker:find()
					end
				end, 1000)
			end),
		})
		pcall(vim.fn.bufload, buf)
		vim.defer_fn(function()
			vim.api.nvim_del_autocmd(id)
		end, 10000)
		return function()
			ctx.async:sleep(2000)
		end
	end

	local bufmap = M.bufmap()
	local filter = opts.filter[vim.bo[buf].filetype]
	if filter == nil then
		filter = opts.filter.default
	end
	---@param kind string?
	local function want(kind)
		kind = kind or "Unknown"
		return type(filter) == "boolean" or vim.tbl_contains(filter, kind)
	end

	local method = opts.workspace and "workspace/symbol" or "textDocument/documentSymbol"
	local p = opts.workspace and { query = ctx.filter.search }
		or { textDocument = vim.lsp.util.make_text_document_params(buf) }

	---@async
	---@param cb async fun(item: snacks.picker.finder.Item)
	return function(cb)
		M.request(buf, method, function()
			return p
		end, function(client, result, params)
			local items = M.results_to_items(client, result, {
				default_uri = params.textDocument and params.textDocument.uri or nil,
				text_with_file = opts.workspace,
				filter = function(item)
					return want(M.symbol_kind(item.kind))
				end,
			})

			-- Fix sorting
			if not opts.workspace then
				table.sort(items, function(a, b)
					if a.pos[1] == b.pos[1] then
						return a.pos[2] < b.pos[2]
					end
					return a.pos[1] < b.pos[1]
				end)
			end

			-- fix last
			local last = {} ---@type table<snacks.picker.finder.Item, snacks.picker.finder.Item>
			for _, item in ipairs(items) do
				item.last = nil
				local parent = item.parent
				if parent then
					if last[parent] then
						last[parent].last = nil
					end
					last[parent] = item
					item.last = true
				end
			end

			for _, item in ipairs(items) do
				item.tree = opts.tree
				item.buf = bufmap[item.file]
				---@diagnostic disable-next-line: await-in-sync
				cb(item)
			end
		end)
	end
end

---Get the interface from the user using fzf-lua
---@param co thread
---@param bufnr integer current buffer number
---@param gopls vim.lsp.Client gopls (go language server)
---@return InterfaceData
function M.get_interface(co, bufnr, gopls)
	Snacks.picker.lsp_workspace_symbols({
		finder = M.symbols,
		prompt = config.options.prompt.interface,
		title = "go-impl",
		---@diagnostic disable-next-line: missing-fields
		icons = {
			kinds = {
				Interface = config.options.icons.interface.text,
			},
		},
		filter = {
			go = {
				"Interface",
			},
		},
		confirm = function(picker, item)
			picker:close()
			coroutine.resume(co, item)
		end,
	})

	local selected = coroutine.yield()

	return {
		col = selected.pos[2] + 1,
		line = selected.pos[1],
		path = selected.file,
		package = selected.package,
	}
end

return M
