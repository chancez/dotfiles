local M = {}

--- Find the nearest block_mapping_pair ancestor of the given node.
---@param node TSNode
---@return TSNode?
local function find_block_mapping_pair(node)
  ---@type TSNode?
  local cur = node
  while cur and cur:type() ~= 'block_mapping_pair' do
    cur = cur:parent()
  end
  return cur
end

--- Collect the key names of all ancestor block_mapping_pairs, outermost first.
---@param pair TSNode
---@return string[]
local function collect_parent_keys(pair)
  local keys = {}
  local current = pair:parent()
  while current do
    if current:type() == 'block_mapping_pair' then
      local key_node = current:named_child(0)
      if key_node then
        table.insert(keys, 1, vim.treesitter.get_node_text(key_node, 0))
      end
    end
    current = current:parent()
  end
  return keys
end

--- Build a structured YAML string for the key-value pair including its ancestor path.
---@param pair TSNode
---@return string?
local function build_yaml_text(pair)
  local key_node = pair:named_child(0)
  local value_node = pair:named_child(1)
  if not key_node or not value_node then
    return nil
  end
  local key_text = vim.treesitter.get_node_text(key_node, 0)
  local value_text = vim.treesitter.get_node_text(value_node, 0)
  local parent_keys = collect_parent_keys(pair)

  local lines = {}
  local indent = ""
  for _, k in ipairs(parent_keys) do
    table.insert(lines, indent .. k .. ":")
    indent = indent .. "  "
  end

  local value_lines = vim.split(value_text, "\n", { plain = true })
  if #value_lines == 1 then
    table.insert(lines, indent .. key_text .. ": " .. value_text)
  else
    table.insert(lines, indent .. key_text .. ":")
    local min_indent = math.huge
    for _, line in ipairs(value_lines) do
      if line:match("%S") then
        min_indent = math.min(min_indent, #(line:match("^(%s*)") or ""))
      end
    end
    local child_indent = indent .. "  "
    for _, line in ipairs(value_lines) do
      if line:match("%S") then
        table.insert(lines, child_indent .. line:sub(min_indent + 1))
      else
        table.insert(lines, "")
      end
    end
  end

  return table.concat(lines, "\n")
end

--- Build a dot-separated key path (e.g. "foo.bar.baz") for the pair at the cursor.
---@param pair TSNode
---@return string?
local function build_key_path(pair)
  local key_node = pair:named_child(0)
  if not key_node then
    return nil
  end
  local parent_keys = collect_parent_keys(pair)
  table.insert(parent_keys, vim.treesitter.get_node_text(key_node, 0))
  return table.concat(parent_keys, ".")
end

--- Get the block_mapping_pair at the cursor, or nil with a warning.
---@return TSNode?
local function get_pair_at_cursor()
  local node = vim.treesitter.get_node()
  if not node then
    vim.notify("No treesitter node at cursor", vim.log.levels.WARN)
    return nil
  end
  local pair = find_block_mapping_pair(node)
  if not pair then
    vim.notify("Not inside a YAML key-value pair", vim.log.levels.WARN)
    return nil
  end
  return pair
end

--- Return the structured YAML text for the key-value pair at the cursor.
---@return string?
function M.get_yaml_text()
  local pair = get_pair_at_cursor()
  if not pair then
    return nil
  end
  return build_yaml_text(pair)
end

--- Return the dot-separated key path for the key at the cursor.
---@return string?
function M.get_key_path()
  local pair = get_pair_at_cursor()
  if not pair then
    return nil
  end
  return build_key_path(pair)
end

--- Yank the structured YAML text to the given register (default: unnamed).
---@param register string?
function M.yank_yaml_text(register)
  local text = M.get_yaml_text()
  if not text then
    return
  end
  register = register or '"'
  vim.fn.setreg(register, text)
  vim.notify("Yanked YAML path to register " .. register)
end

--- Yank the dot-separated key path to the given register (default: unnamed).
---@param register string?
function M.yank_key_path(register)
  local path = M.get_key_path()
  if not path then
    return
  end
  register = register or '"'
  vim.fn.setreg(register, path)
  vim.notify("Yanked key path to register " .. register)
end

return M
