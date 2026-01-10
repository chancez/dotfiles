require("lazy").setup("plugins", {
  -- do not automatically check for plugin updates
  checker = {
    enabled = false
  },
  rocks = {
    enabled = false
  },
  change_detection = {
    enabled = true,
    notify = false,
  },
  dev = {
    path = "~/projects",
    patterns = {
      "chancez",
      "telescope-hierarchy",
    },
    fallback = true, -- Fallback to git when local plugin doesn't exist
  },
})
