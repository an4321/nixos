local dir = require("nvim.dir")
local selected = {}

local function create()
	local input = vim.fn.input("Create: ")
	if not input or input == "" then return end

	for _, t in ipairs(vim.split(input, "%s+", { trimempty = true })) do
		vim.fn.mkdir(vim.fn.fnamemodify(t, ":h"), "p")

		if t:sub(-1) ~= "/" then
			local fd = io.open(t, "a")
			if fd then fd:close() end
		end
	end

	dir._reload()
end

local function current_item()
	local file = vim.api.nvim_get_current_line()
	if vim.fn.filereadable(file) == 0 then file = "" end
	local directory = vim.api.nvim_buf_get_name(0)
	return directory .. file
end

local function print_sel()
	print("selected:")
	for index, value in ipairs(selected) do print(index, value) end
	print("---")
end

local function select()
	local t = current_item()
	if not t then return end -- Guard against nil items

	for i, v in ipairs(selected) do
		if v == t then
			table.remove(selected, i)
			print("removed: " .. v)
			print_sel()
			return
		end
	end

	table.insert(selected, t)
	print_sel()
end

vim.api.nvim_create_autocmd("User", {
	pattern = "DirReadPost",
	callback = function(args)
		local opts = { buf = args.buf, remap = true }
		vim.keymap.set("n", "h", "-", opts)
		vim.keymap.set("n", "l", "<CR>", opts)
		vim.keymap.set("n", "a", create, opts)
		vim.keymap.set("n", "s", select, {buf = args.buf})
	end
})

-- i dont like this.
vim.api.nvim_create_autocmd("BufEnter", {
	group = vim.api.nvim_create_augroup("PruneDirBuffers", { clear = true }),
	callback = function() vim.cmd("Prune") end,
})
vim.api.nvim_create_user_command("Prune", function()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			local filetype = vim.bo[buf].filetype
			local buftype = vim.bo[buf].buftype
			-- todo if its nowrite and name ends with /
			if buftype == "nowrite" then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end
	end
end)

-- vim.keymap.set("n", "<c-r>", function() dir._reload() end, opts) -- R already does that
-- vim.keymap.set("n", "r", rename, opts)

-- instead of ding cut / copy directly, bind s to select and c to clear selections
-- unselct item if s if pressed again
-- maybe i can do p to copy paste and shift + p to cut paste
-- maybe ctrl + a to select all
-- maybe maybe ge to edit the selected files
-- maybe a bind to reload
-- ofc R to bulk rename
-- or maybe r to rename and on save if only 1 file was updated then no confirm
-- where on rename the cursor moves to end in insert mode.

