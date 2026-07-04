local M = {}

local defaults = {
  anki_port = 8765,
  deck_name = "Default",
  model_name = "Basic",
}

local config = {}

function M.setup(opts)
  config = vim.tbl_extend('force', defaults, opts or {})
end

local function markdown_to_html(text)
  -- Convert display math: $$ ... $$ -> \[ ... \]
  text = text:gsub("%$%$(.-)%$%$", "\\[%1\\]")
  
  -- Convert inline math: $ ... $ -> \( ... \)
  text = text:gsub("%$([^%$]-)%$", "\\(%1\\)")
  
  -- Convert markdown to HTML
  -- Bold: **text** -> <b>text</b>
  text = text:gsub("%*%*(.-)%*%*", "<b>%1</b>")
  
  -- Italic: *text* -> <i>text</i> (but not inside links or already bold)
  text = text:gsub("%*([^*]-)%*", "<i>%1</i>")
  
  -- Wiki links: [[text|display]] -> display (just show the display text)
  text = text:gsub("%[%[([^|%]]+)|([^%]]+)%]%]", "%2")
  text = text:gsub("%[%[([^%]]+)%]%]", "%1")
  
  -- Line breaks
  text = text:gsub("\n", "<br>")
  
  return text
end

local function extract_lemma_and_proof()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  
  local lemma = nil
  local body_lines = {}
  local found_title = false
  local frontmatter_end = 0
  
  -- Skip YAML frontmatter
  if lines[1] and lines[1]:match("^%-%-%-") then
    for i = 2, #lines do
      if lines[i]:match("^%-%-%-") then
        frontmatter_end = i
        break
      end
    end
  end
  
  -- Process lines after frontmatter
  for i = frontmatter_end + 1, #lines do
    local line = lines[i]
    
    -- Extract lemma from ### heading and remove the ### prefix
    if line:match("^###") then
      lemma = line:gsub("^###%s*", ""):match("^%s*(.-)%s*$")
      found_title = true
    -- Stop at --- separator (but not the frontmatter one)
    elseif line:match("^%-%-%-") and found_title then
      break
    -- Capture everything after the title until ---
    elseif found_title then
      table.insert(body_lines, line)
    end
  end
  
  local body = table.concat(body_lines, "\n")
  
  return lemma, body
end

local function send_to_anki(front, back)
  -- Convert markdown to HTML
  front = markdown_to_html(front)
  back = markdown_to_html(back)
  
  local payload = {
    action = "addNote",
    version = 6,
    params = {
      note = {
        deckName = config.deck_name,
        modelName = config.model_name,
        fields = {
          Front = front,
          Back = back,
        },
        options = {
          allowDuplicate = false,
        },
      },
    },
  }
  
  local json = vim.fn.json_encode(payload)
  
  -- Use a temp file to avoid shell escaping issues
  local temp_file = os.tmpname()
  local f = io.open(temp_file, "w")
  f:write(json)
  f:close()
  
  local curl_cmd = string.format(
    "curl -s -X POST http://localhost:%d -d @%s -H 'Content-Type: application/json' 2>&1",
    config.anki_port,
    temp_file
  )
  
  vim.notify("Attempting to connect to AnkiConnect on port " .. config.anki_port, vim.log.levels.INFO)
  
  local handle = io.popen(curl_cmd)
  local result = handle:read("*a")
  handle:close()
  
  -- Clean up temp file
  os.remove(temp_file)
  
  if not result or result == "" then
    vim.notify("AnkiConnect returned empty response. Is Anki running on port " .. config.anki_port .. "?", vim.log.levels.ERROR)
    return false
  end
  
  local ok, response = pcall(vim.fn.json_decode, result)
  if not ok then
    vim.notify("Failed to parse AnkiConnect response: " .. result, vim.log.levels.ERROR)
    return false
  end
  
  if response.error then
    vim.notify("Anki error: " .. tostring(response.error), vim.log.levels.ERROR)
    return false
  else
    vim.notify("Card created! ID: " .. tostring(response.result), vim.log.levels.INFO)
    return true
  end
end

function M.create_card()
  if not next(config) then
    M.setup()
  end
  
  local lemma, body = extract_lemma_and_proof()
  
  if not lemma or body == "" then
    vim.notify("Could not extract lemma and body. Ensure file has '### ' header.", vim.log.levels.ERROR)
    return
  end
  
  vim.notify("Lemma: " .. lemma, vim.log.levels.INFO)
  vim.notify("Creating card...", vim.log.levels.INFO)
  send_to_anki(lemma, body)
end

function M.set_deck()
  local deck_name = vim.fn.input("Enter deck name: ")
  if deck_name ~= "" then
    config.deck_name = deck_name
    vim.notify("Deck set to: " .. deck_name, vim.log.levels.INFO)
  end
end

return M
