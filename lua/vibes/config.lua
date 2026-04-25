local M = {}

--- Default configuration.
M.defaults = {
	-- commands are hardcoded
	commands = {
		toggle_window = "VibesToggle", -- toggle window
		window_close = "VibesClose", -- close open window
		vibes_load = "VibesLoad", -- load new playlist
		vibes_delete = "VibesDelete", -- delete playlist
	},

	-- Keymaps have a corresponding user command defined above.
	keymaps = {
		toggle_window = "<leader>vv",
		window_close = "<leader>vc",
	},

	api = {
		key = nil,
	},

	buf = {
		number = false,   -- line numbers
		relativenumber = false, -- relative line numbers
		keymaps = {
			quit = { "q", "<Esc>" },
		},
	},

	window = {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		title = " vibes.nvim ",
		title_pos = "center",
		height = function() return math.floor(0.6 * vim.o.lines) end,
		width = function() return math.floor(0.6 * vim.o.columns) end,
		row = function() return math.floor(0.4 * vim.o.lines / 2) end,
		col = function() return math.floor(0.4 * vim.o.columns / 2) end,
	}
}

---Sets the opts configuration table.
---@param opts table?
M.set = function(opts)
	opts = opts or {}
	local defaults = M.defaults
	M.opts = vim.tbl_deep_extend("force", defaults, opts)
end

return M
