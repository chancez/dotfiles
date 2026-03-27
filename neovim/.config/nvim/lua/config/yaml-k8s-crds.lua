-- Automatically attach the correct Kubernetes schema to YAML files based on
-- their content, and fall back to the default LSP configuration if no specific
-- schema is found.
-- Based on https://www.reddit.com/r/neovim/comments/1iykmqc/improving_kubernetes_yaml_support_in_neovim_crds/
-- TODO: Look into the improvements added in https://github.com/manzanit0/k8s-whisper.nvim

local curl = require 'plenary.curl'
local M = {
  schemas_catalog = 'datreeio/CRDs-catalog',
  schema_catalog_branch = 'main',
  github_base_api_url = 'https://api.github.com/repos',
  github_headers = {
    Accept = 'application/vnd.github+json',
    ['X-GitHub-Api-Version'] = '2022-11-28',
  },
  schema_cache = {}, -- Cache for downloaded schemas
}
M.schema_url = 'https://raw.githubusercontent.com/' .. M.schemas_catalog .. '/' .. M.schema_catalog_branch

-- Download and cache the list of CRDs
M.list_github_tree = function()
  if M.schema_cache.trees then
    return M.schema_cache.trees -- Return cached data if available
  end

  local url = M.github_base_api_url .. '/' .. M.schemas_catalog .. '/git/trees/' .. M.schema_catalog_branch
  local response = curl.get(url, { headers = M.github_headers, query = { recursive = 1 } })
  local body = vim.fn.json_decode(response.body)
  local trees = {}
  for _, tree in ipairs(body.tree) do
    if tree.type == 'blob' and tree.path:match '%.json$' then
      table.insert(trees, tree.path)
    end
  end
  M.schema_cache.trees = trees -- Cache the list of CRDs
  return trees
end

-- Extract apiVersion and kind from YAML content
M.extract_api_version_and_kind = function(buffer_content)
  -- Remove the document separator (---) if present
  buffer_content = buffer_content:gsub('^%-%-%-%s*\n', '')
  -- Scan the entire file for apiVersion and kind
  local api_version = buffer_content:match('apiVersion:%s*([%w%.%/%-]+)')
  local kind = buffer_content:match('kind:%s*([%w%-]+)')
  return api_version, kind
end

-- Normalize apiVersion and kind to match CRD schema naming convention
M.normalize_crd_name = function(api_version, kind)
  if not api_version or not kind then
    return nil
  end
  -- Split apiVersion into group and version (e.g., "argoproj.io/v1alpha1" -> "argoproj.io", "v1alpha1")
  local group, version = api_version:match('([^/]+)/([^/]+)')
  if not group or not version then
    return nil
  end
  -- Normalize kind to lowercase
  local normalized_kind = kind:lower()
  -- Construct the CRD name in the format: <group>/<kind>_<version>.json
  return group .. '/' .. normalized_kind .. '_' .. version .. '.json'
end

-- Match the CRD schema based on apiVersion and kind
M.match_crd = function(buffer_content)
  local api_version, kind = M.extract_api_version_and_kind(buffer_content)
  if not api_version or not kind then
    return nil
  end
  local crd_name = M.normalize_crd_name(api_version, kind)
  if not crd_name then
    return nil
  end
  local all_crds = M.list_github_tree()
  for _, crd in ipairs(all_crds) do
    if crd:match(crd_name) then
      return crd
    end
  end
  return nil
end

-- Attach a schema to the buffer
M.attach_schema = function(schema_url, description)
  local clients = vim.lsp.get_clients({ name = 'yamlls' })
  if #clients == 0 then
    vim.notify('yaml-language-server is not active.', vim.log.levels.WARN)
    return
  end
  local yaml_client = clients[1]

  -- Update the yaml.schemas setting for the current buffer
  yaml_client.config.settings = yaml_client.config.settings or {}
  yaml_client.config.settings.yaml = yaml_client.config.settings.yaml or {}
  yaml_client.config.settings.yaml.schemas = yaml_client.config.settings.yaml.schemas or {}

  -- Attach the schema only for the current buffer
  yaml_client.config.settings.yaml.schemas[schema_url] = '*.yaml'

  -- Notify the server of the configuration change
  yaml_client.notify('workspace/didChangeConfiguration', {
    settings = yaml_client.config.settings,
  })
  vim.notify('Attached schema: ' .. description, vim.log.levels.INFO)
end

-- Get the correct Kubernetes schema URL based on apiVersion and kind
M.get_kubernetes_schema_url = function(api_version, kind)
  local version = api_version:match('/([%w%-]+)$') or api_version
  local schema_name

  -- Check if the schema file exists with the version suffix
  schema_name = kind:lower() .. '-' .. version .. '.json'
  local url_with_version = 'https://raw.githubusercontent.com/yannh/kubernetes-json-schema/refs/heads/master/master/' ..
      schema_name

  -- Check if the schema file exists without the version suffix
  local url_without_version = 'https://raw.githubusercontent.com/yannh/kubernetes-json-schema/refs/heads/master/master/' ..
      kind:lower() .. '.json'

  -- Try to fetch the schema with the version suffix first
  local response_with_version = curl.get(url_with_version, { headers = M.github_headers })
  if response_with_version.status == 200 then
    return url_with_version
  end

  -- If the schema with the version suffix doesn't exist, try without the version suffix
  local response_without_version = curl.get(url_without_version, { headers = M.github_headers })
  if response_without_version.status == 200 then
    return url_without_version
  end

  -- If neither exists, return nil or fallback to a default schema
  return nil
end

M.init = function(bufnr)
  -- Check if the schema has already been attached to this buffer
  if vim.b[bufnr].schema_attached then
    return
  end
  vim.b[bufnr].schema_attached = true -- Mark the schema as attached

  local buffer_content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
  local crd = M.match_crd(buffer_content)
  if crd then
    -- Attach the CRD schema
    local schema_url = M.schema_url .. '/' .. crd
    M.attach_schema(schema_url, 'CRD schema for ' .. crd)
  else
    -- Check if the file is a Kubernetes YAML file
    local api_version, kind = M.extract_api_version_and_kind(buffer_content)
    if api_version and kind then
      -- Attach the Kubernetes schema
      local kubernetes_schema_url = M.get_kubernetes_schema_url(api_version, kind)
      if kubernetes_schema_url then
        M.attach_schema(kubernetes_schema_url, 'Kubernetes schema for ' .. kind)
      else
        vim.notify('No Kubernetes schema found for ' .. kind .. ' with apiVersion ' .. api_version, vim.log.levels.WARN)
      end
    else
      -- Fall back to the default LSP configuration
      vim.notify('No CRD or Kubernetes schema found. Falling back to default LSP configuration.', vim.log.levels.WARN)
    end
  end
end

return M
