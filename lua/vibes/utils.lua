local M = {}

---@class vibes.window_state
---@field buf integer
---@field win integer
---@field location string?

---@class vibes.floating_window_config : vim.api.keyset.win_config
---@field row number|function
---@field col number|function
---@field width integer|function
---@field height integer|function

---@class vibes.buffer
---@field number boolean
---@field relativenumber boolean
---@field window vibes.floating_window_config

M.vibes_augroup = vim.api.nvim_create_augroup("vibes", { clear = true })

M.data_path = vim.fn.stdpath("data") .. "/vibes"
if vim.fn.isdirectory(M.data_path) == 0 then
	vim.fn.mkdir(M.data_path, "p", "448")
end

---Sets the keymap(s).
---@param mode string|string[]
---@param keybind (string|string[])?
---@param action string|function
---@param opts table?
M.set_keymaps = function(mode, keybind, action, opts)
	if keybind == nil then
		return
	end
	if type(keybind) == "string" then
		if #keybind ~= 0 then
			vim.keymap.set(mode, keybind, action, opts)
		end
		return
	end
	for _, n in ipairs(keybind) do
		if #n ~= 0 then
			vim.keymap.set(mode, n, action, opts)
		end
	end
end

---@param path string
---@return boolean
M.file_exists = function(path)
	local f = io.open(path, "r")
	if f then f:close() end
	return f ~= nil
end

---@param path string
---@return boolean, any
M.load_json_file = function(path)
	local f = io.open(path, "r")
	if not f then return false, {} end
	local data = f:read("*a")
	f:close()
	return true, vim.fn.json_decode(data)
end

---@param path string
---@param data table
---@return boolean
M.write_json_file = function(path, data)
	local f = io.open(path, "w")
	if not f then return false end
	f:write(vim.fn.json_encode(data))
	f:close()
	return true
end

return M
