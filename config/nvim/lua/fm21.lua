local dir = require("nvim.dir")
local cut_file = nil
local copy_file = nil

local function prompt(text)
	local res = vim.fn.input(text)
	if not res or res == "" then
		return nil
	end
	return res
end

local function current_file()
	local line = vim.api.nvim_get_current_line()
	if vim.fn.filereadable(line) == 0 then
		return nil
	end
	return line
end

local function current_dir()
	return vim.api.nvim_buf_get_name(0)
end

local function create()
	local file_folder = prompt("New file/folder: ")
	if not file_folder then return end

	local is_folder = file_folder:sub(-1) == "/"

	if is_folder then
		vim.cmd("!mkdir " .. file_folder)
	else
		vim.cmd("!touch " .. file_folder)
	end
	dir._reload()
end


local function delete()
	local file = current_file()
	if not file then return end

	vim.cmd("!rm " ..  file)
	dir._reload()
end

local function rename()
	local file = current_file()
	if not file then return end

	local new_file = prompt("New name: ")
	if not new_file then return end

	vim.cmd("!mv " .. file .. " " ..  new_file)
	dir._reload()
end


local function cut()
	local file = current_file()
	if not file then return end

	local directory = current_dir()

	print("CUT: " .. file)
	cut_file = directory .. "/" .. file
	copy_file = nil
end


local function copy()
	local file = current_file()
	if not file then return end

	local directory = current_dir()

	print("COPY: " .. file)
	copy_file = directory .. "/" .. file
	cut_file = nil
end

local function dest_file(file)
	local split = vim.split(file, "/")
	local name = split[#split]
	local dest = current_dir() .. "/" .. name
	return dest
end

local function cut_paste(file)
	local dest = dest_file(file)
	vim.cmd("!mv " .. file .. " " .. dest)
	dir._reload()
	cut_file = nil
	copy_file = nil
end

local function copy_paste(file)
	local dest = dest_file(file)
	vim.cmd("!cp " .. file .. " " .. dest)
	dir._reload()
	cut_file = nil
	copy_file = nil
end

local function paste()
	if cut_file then
		cut_paste(cut_file)
		return
	end
	if copy_file then
		copy_paste(copy_file)
		return
	end
end

vim.api.nvim_create_autocmd("User", {
	pattern = "DirReadPost",
	callback = function(args)
		local opts = { buf = args.buf }
		vim.keymap.set("n", "a", create, opts)
		vim.keymap.set("n", "r", rename, opts)
		vim.keymap.set("n", "d", delete, opts)
		vim.keymap.set("n", "x", cut, opts)
		vim.keymap.set("n", "y", copy, opts)
		vim.keymap.set("n", "p", paste, opts)
	end
})

