local config = require("vibes.config")
local ui = require("vibes.ui")
local utils = require("vibes.utils")

local M = {}

local function get_input(msg)
	local status, out = pcall(vim.fn.input, msg)
	if not status or out == "" then
		return nil
	end
	vim.schedule(function()
		vim.print("")
		vim.cmd("messages clear")
	end)
	return out
end

---Applies configuration from config.opts.
local function apply_config()
	local opts = config.opts

	vim.api.nvim_create_user_command("VibesToggle", ui.handle_window, {})
	vim.api.nvim_create_user_command("VibesClose", ui.close_window, {})
	vim.api.nvim_create_user_command("VibesLoad", function()
		local api_key
		if opts.api.key == nil then
			api_key = get_input("Enter the YouTube API key: ")
			if not api_key then
				return
			end
		elseif type(opts.api.key) == "string" then
			if utils.file_exists(opts.api.key) then
				api_key = io.lines(opts.api.key)()
			else
				api_key = opts.api.key
			end
		elseif type(opts.api.key) == "function" then
			api_key = opts.api.key()
			assert(type(api_key) == "string", "AssertionError: API key given by custom function is not a string.")
		else
			error("Error: API key not found. Invalid configuration.")
		end
		vim.schedule(function()
			local current_file_path = debug.getinfo(1).source:sub(2)
			local current_dir = vim.fs.joinpath(vim.fs.dirname(current_file_path), "../../api")
			local venv_path = vim.fs.joinpath(current_dir, ".venv")
			local python_bin = vim.fs.joinpath(venv_path, "bin", "python3")
			local pip_bin = vim.fs.joinpath(venv_path, "bin", "pip")
			local py_script = vim.fs.joinpath(current_dir, "api.py")

			local stats = vim.uv.fs_stat(venv_path)
			if not stats then
				vim.print("Setting up virtual environment...")
				vim.system({ "python3", "-m", "venv", venv_path }):wait()
				vim.print("Installing requirements...")
				vim.system({ pip_bin, "install", "google-api-python-client" }):wait()
			end
			local playlist_id = get_input("Enter playlist ID: ")
			if not playlist_id then
				return
			end
			local out = vim.system({ python_bin, py_script, utils.data_path, playlist_id }, {
				env = { YT_API_KEY = api_key },
				text = true
			}):wait()
			vim.schedule(function()
				if out.code == 0 then
					vim.print(out.stdout)
				else
					vim.print(out.stderr)
				end
			end)
		end)
	end
	, {})
	vim.api.nvim_create_user_command("VibesDelete", function()
		local name = get_input("Enter playlist name: ")
		if not name then
			return
		end
		local _ = os.remove(utils.data_path .. "/" .. name .. ".json")
	end
	, {})

	for action, keybind in pairs(opts.keymaps) do
		utils.set_keymaps("n", keybind, string.format("<cmd>%s<CR>", opts.commands[action]))
	end
end

---@param opts table?
M.setup = function(opts)
	opts = opts or {}
	config.set(opts)
	apply_config()
end

return M
