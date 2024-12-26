local ts_utils = require("nvim-treesitter.ts_utils")

local M = {}

---Get the gopls client for the current buffer
---@param bufnr integer The buffer number
---@return vim.lsp.Client? client The gopls client
function M.get_gopls(bufnr)
	local clients = vim.lsp.get_clients({ bufnr = bufnr })

	for _, client in ipairs(clients) do
		if client.name == "gopls" then
			return client
		end
	end
end

---Try to get the current struct name under the cursor
---@return string? struct_name The struct name
function M.get_struct_name_at_cursor()
	local node = ts_utils.get_node_at_cursor()

	while node and node:type() ~= "type_declaration" do
		node = node:parent()
	end

	if not node then
		return
	end

	for child, _ in node:iter_children() do
		-- Tree-sitter node structure:
		-- (type_declaration
		--   (type_spec
		--   name: (type_identifier)
		--   type: (struct_type
		--       (field_declaration_list
		--       (field_declaration
		--       ...

		if child:type() == "type_spec" then
			---@type table<string, TSNode>
			local nodes = {}

			for grandchild, field in child:iter_children() do
				nodes[field] = grandchild
			end

			if not nodes["type"] or not nodes["name"] then
				return
			end

			if nodes["type"]:type() ~= "struct_type" then
				return
			end

			local node_text = vim.treesitter.get_node_text(nodes["name"], 0)
			if not node_text then
				return
			end

			return node_text
		end
	end
end

---Predict the abbreviation for the current struct
---@param struct_name? string The Go struct name
---@return string abbreviation The predicted abbreviation
function M.predict_abbreviation(struct_name)
	if not struct_name then
		return ""
	end

	local abbreviation = ""
	abbreviation = abbreviation .. string.sub(struct_name, 1, 1)
	for i = 2, #struct_name do
		local char = string.sub(struct_name, i, i)
		if char == string.upper(char) and char ~= string.lower(char) then
			abbreviation = abbreviation .. char
		end
	end
	return string.lower(abbreviation) .. " *" .. struct_name
end

---Check the validity of the go receiver string
---@param receiver string? The receiver string
---@return boolean result the receiver is valid
function M.is_valid_recevier(receiver)
	if not receiver or #receiver == 0 then
		return false
	end

	return string.match(receiver, "^%a+%s%*?%a+$") ~= nil
end

return M
