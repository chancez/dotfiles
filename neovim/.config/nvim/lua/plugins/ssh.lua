return {
  "nosduco/remote-sshfs.nvim",
  dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
  opts = {
    handlers = {
      on_connect = {
        change_dir = true, -- when connected change vim working directory to mount point
      },
    },
    ui = {
      confirm = {
        connect = false,
        change_dir = false,
      },
    },
  },
  config = function(_, opts)
    require('remote-sshfs').setup(opts)
    require('telescope').load_extension 'remote-sshfs'
  end
}
