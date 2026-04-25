local config = require("vibes.config")
local utils = require("vibes.utils")

local M = {}

local state = {
	win = -1,
	buf = -1,
	json_table = {},
	contents = {}
}

M.get_buffer = function()
	return state.buf
end

---Convert `vibes.floating_window_config` to `vim.api.keyset.win_config`
---by running the functions associated with the `row`, `col`, `width`, and `height` attributes
---(if they are functions).
---@param opts vibes.floating_window_config
---@return vim.api.keyset.win_config
local calculate_floating_win_config = function(opts)
	local loaded_opts = {}
	for k, v in pairs(opts) do
		local loaded_v = v
		if k == "row" or k == "col" or k == "width" or k == "height" and type(v) == "function" then
			loaded_v = v()
			assert(type(loaded_v) == "number")
		end
		loaded_opts[k] = loaded_v
	end
	return loaded_opts
end

---Creates a floating window.
---@param buf integer
---@param opts vibes.floating_window_config
---@return vibes.window_state
local create_floating_window = function(buf, opts)
	-- Buffer creation
	if not vim.api.nvim_buf_is_valid(buf) then
		buf = vim.api.nvim_create_buf(false, true)
	end

	-- Load configuration
	local loaded_opts = calculate_floating_win_config(opts)

	-- Window configuration
	local win = vim.api.nvim_open_win(buf, true, loaded_opts)

	return { buf = buf, win = win }
end

---Converts data stored in JSON files to user view.
---@param data any
---@return table
local function data_to_buf(data)
	local out = {}
	for _, n in ipairs(data["playlist"]) do
		table.insert(out, n["title"])
	end
	return out
end

---Loads file into buffer.
---@param filename string
M.load_file = function(filename)
	local buf = state.buf
	local exists, data = utils.load_json_file(filename)
	if exists then
		state.json_table = data
		local contents = data_to_buf(data)
		vim.bo[buf].modifiable = true
		vim.bo[buf].readonly = false
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, contents)
		vim.bo[buf].modifiable = false
		vim.bo[buf].readonly = true
	end
	vim.keymap.set("n", "<Enter>", function()
		local cursor = vim.api.nvim_win_get_cursor(state.win)
		local line = cursor[1]
		local url = string.format("https://www.youtube.com/watch?v=%s&list=%s", state.json_table["playlist"][line]["id"],
			state.json_table["id"])
		vim.system({ "xdg-open", url }, { detach = true })
		M.close_window()
	end, { buffer = state.buf })
	vim.keymap.set("n", "<BS>", M.load_buf, { buffer = state.buf })
	vim.keymap.set("n", "-", M.load_buf, { buffer = state.buf })
end

---Loads buffer.
M.load_buf = function()
	local buf
	if vim.api.nvim_buf_is_valid(state.buf) then
		buf = state.buf
	else
		buf = vim.api.nvim_create_buf(false, true)
		state.buf = buf
	end
	local contents = {}
	for filename, type in vim.fs.dir(utils.data_path) do
		if type ~= "file" then
			goto continue
		end
		table.insert(contents, vim.fn.fnamemodify(filename, ":r"))
		::continue::
	end
	state.contents = contents
	vim.bo[buf].modifiable = true
		vim.bo[buf].readonly = false
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, state.contents)
	vim.bo[buf].modifiable = false
		vim.bo[buf].readonly = true
	vim.keymap.set("n", "<Enter>", function()
		M.load_file(utils.data_path .. "/" .. vim.api.nvim_get_current_line() .. ".json")
	end, { buffer = state.buf })
end

---Creates a floating window window.
M.handle_window = function()
	if vim.api.nvim_win_is_valid(state.win) then
		M.close_window()
		return
	end
	M.load_buf()
	local opts = config.opts
	state = create_floating_window(state.buf, config.opts.window)

	local win = state.win
	local buf = state.buf
	vim.wo[win].number = opts.number
	vim.wo[win].relativenumber = opts.relativenumber
	vim.bo[buf].readonly = true
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
	vim.api.nvim_buf_set_name(buf, "vibes window")

	vim.api.nvim_create_autocmd("WinLeave", {
		buffer = buf,
		once = true,
		callback = function()
			if vim.api.nvim_win_is_valid(win) then
				M.close_window()
			end
		end,
		group = utils.cmdmacro_augroup
	})
	vim.api.nvim_create_autocmd("VimResized", {
		buffer = state.buf,
		callback = function()
			local loaded_opts = calculate_floating_win_config(opts.window)
			vim.api.nvim_win_set_config(state.win, loaded_opts)
			vim.api.nvim_buf_set_name(state.buf, "vibes window")
		end,
		group = utils.cmdmacro_augroup
	})
	utils.set_keymaps("n", config.opts.buf.keymaps.quit, M.close_window, { buffer = state.buf })
end

---Close window.
M.close_window = function()
	local win = state.win
	local buf = state.buf
	if not vim.api.nvim_win_is_valid(win) then
		return
	end
	vim.cmd("clearjumps")
	vim.api.nvim_win_hide(win)
	if vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_set_name(buf, "")
	else
		buf = vim.api.nvim_create_buf(false, true)
	end
	state.win = -1
	state.json_table = {}
end

return M
