local M = {}

local defaults = {
  anki_port = 8765,
  deck_name = "Math",
  model_name = "Proof",
}

local config = {}

function M.setup(opts)
  config = vim.tbl_extend('force', defaults, opts or {})
end

local function extract_lemma_and_proof()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  
  local lemma = nil
  for i, line in ipairs(lines) do
    if line:match("^###") then
      lemma = line:gsub("^###\\s*", "")
      break
    end
  end
  
  local proof_start = nil
  for i, line in ipairs(lines) do
    if line:match("^%*%*Proof%.%*%*") then
      proof_start = i
      break
    end
  end
  
  local proof = nil
  if proof_start then
    proof = table.concat(vim.list_slice(lines, proof_start, -1), "\n")
  end
  
  return lemma, proof
end

local function send_to_anki(front, back)
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
  local curl_cmd = string.format(
    "curl -s -X POST http://localhost:%d --data '%s' -H 'Content-Type: application/json'",
    config.anki_port,
    json:gsub("'", "'\\''")
  )
  
  local handle = io.popen(curl_cmd)
  local result = handle:read("*a")
  handle:close()
  
  local response = vim.fn.json_decode(result)
  
  if response.error then
    vim.notify("Anki error: " .. response.error, vim.log.levels.ERROR)
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
  
  local lemma, proof = extract_lemma_and_proof()
  
  if not lemma or not proof then
    vim.notify("Could not extract lemma and proof. Ensure file has '### ' header and '**Proof.**' section.", vim.log.levels.ERROR)
    return
  end
  
  vim.notify("Creating card...", vim.log.levels.INFO)
  send_to_anki(lemma, proof)
end

function M.set_deck()
  local deck_name = vim.fn.input("Enter deck name: ")
  if deck_name ~= "" then
    config.deck_name = deck_name
    vim.notify("Deck set to: " .. deck_name, vim.log.levels.INFO)
  end
end

return M
