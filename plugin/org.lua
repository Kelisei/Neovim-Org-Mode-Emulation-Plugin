if vim.g.loaded_org_nvim then
	return
end
vim.g.loaded_org_nvim = true

require("org").setup()
