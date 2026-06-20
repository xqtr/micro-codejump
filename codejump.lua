VERSION = "1.0.0"

local config = import("micro/config")
local shell = import("micro/shell")
local micro = import("micro")

local patterns = {
    python = {
        "^%s*def%s+",
        "^%s*async%s+def%s+",
        "^%s*class%s+",
    },

    go = {
        "^%s*func%s+",
    },

    rust = {
        "^%s*fn%s+",
        "^%s*impl%s+",
        "^%s*trait%s+",
    },

    c = {
        "^%s*[%w_%*]+%s+[%w_%*]+%s*%b()%s*{?$",
    },

    cpp = {
        "^%s*[%w_:~<>%*&]+%s+[%w_:~<>]+%s*%b()%s*{?$",
        "^%s*[cC]lass%s+",
        "^%s*[sS]]truct%s+",
    },

    pascal = {
        "^%s*[fF]unction%s+",
        "^%s*[pP]rocedure%s+",
        "^%s*[cC]onstructor%s+",
        "^%s*[dD]estructor%s+",
        "^%s*[uU]ses",
    },
    
    unknown = {
        "^%s*[fF]unction%s+",
        "^%s*[cC]lass%s+",
        "^%s*[sS]truct%s+",
        "^%s*[iI]nterface%s+",
        "^%s*[tT]rait%s+",
        "^#+%s+",
    },

    markdown = {
        "^#%s+",
        "^##%s+",
        "^###%s+",
        "^####%s+",
        "^#####%s+",
        "^######%s+",
    },
}

function init()
    config.MakeCommand("codejump", codejumpCommand, config.NoComplete)
    config.MakeCommand("defjumpdown", NavFuncNext, config.NoComplete)
  	config.MakeCommand("defjumpup", NavFuncPrev, config.NoComplete)
  	config.MakeCommand("showcurrentfunction", ShowCurrentFunction, config.NoComplete)
    config.MakeCommand("searchword", SearchWord, config.NoComplete)
  
  	config.TryBindKey("F4", "command:codejump", true)
  	config.TryBindKey("Ctrl-Up", "command:defjumpup", true)
  	config.TryBindKey("Ctrl-Down", "command:defjumpdown", true)
  	config.TryBindKey("F5", "command:showcurrentfunction", true)
    config.TryBindKey("F9", "command:searchword", true)
   
  	config.AddRuntimeFile("codejump", config.RTHelp, "help/codejump.md")
end

function get_analyzer_path()
    return os.getenv("HOME") .. "/.config/micro/plug/codejump/code_analyzer.py"
end

function codejumpCommand(bp) -- bp BufPane
	local filename = bp.Buf.Path
	local cmd = string.format("bash -c \"'%s' '%s'|fzf --layout=reverse|cut -d':' -f1\"", get_analyzer_path(), filename)
	local out = shell.RunInteractiveShell(cmd, false, true)
	if tonumber(out) == nil then
		micro.InfoBar():Message("Jump cancelled.")
		return
	end
	local linenum = tonumber(out)-1
	bp.Cursor.Y = linenum
	micro.InfoBar():Message(string.format("Jumped to line ", linenum))
end

function lineMatches(ft, line)
    local pats = patterns[ft]

    if pats == nil then
        return false
    end

    for _, pat in ipairs(pats) do
        if line:match(pat) then
            return true
        end
    end

    return false
end

function findFunction(bp, forward)
    local buf = bp.Buf
    local cur = bp.Cursor

    local current = cur.Y
    local last = buf:LinesNum() - 1

    local step = forward and 1 or -1
    local line = current + step
    
    local ft = buf.Settings["filetype"]

    while line >= 0 and line <= last do
        local txt = buf:Line(line)

        if txt and lineMatches(ft, txt) then
            cur.Y = line
            cur.X = 0

            if bp.Relocate ~= nil then
                bp:Relocate()
            end

            return
        end

        line = line + step
    end

    micro.InfoBar():Message(
        forward and "No next function found"
                or "No previous function found"
    )
end

function NavFuncNext(bp)
    findFunction(bp, true)
end

function NavFuncPrev(bp)
    findFunction(bp, false)
end

-- NEW: Find and display the current function
-- Enhanced version: Show just the function name (optional)
function ShowCurrentFunction(bp)
    local buf = bp.Buf
    local cur = bp.Cursor
    local currentLine = cur.Y
    local ft = buf.Settings["filetype"] or "unknown"
    
    local foundLine = -1
    local foundText = ""
    
    -- First check if we're on a function line
    local currentLineText = buf:Line(currentLine)
    if currentLineText and lineMatches(ft, currentLineText) then
        foundLine = currentLine
        foundText = currentLineText
    else
        -- Search upward for function
        local line = currentLine
        while line >= 0 do
            local txt = buf:Line(line)
            if txt and lineMatches(ft, txt) then
                foundLine = line
                foundText = txt
                break
            end
            line = line - 1
        end
    end
    
    if foundLine >= 0 and foundText ~= "" then
        -- Extract just the function name (between def/class and the opening parenthesis or colon)
        local cleanText = foundText:gsub("^%s+", "") -- Remove leading spaces
        
        -- For Python: extract function name after 'def' or 'async def'
        if ft == "python" then
            local name = cleanText:match("def%s+([%w_]+)") or 
                        cleanText:match("async%s+def%s+([%w_]+)") or
                        cleanText:match("class%s+([%w_]+)")
            if name then
                cleanText = cleanText:gsub("(%s*[:{])$", "") -- Remove trailing colon or brace
                micro.InfoBar():Message(string.format("%s (line %d)", cleanText, foundLine + 1))
                return
            end
        end
        
        -- For other languages: just show the line stripped of leading whitespace
        local displayText = foundText:gsub("^%s+", "")
        micro.InfoBar():Message(string.format("%s (line %d)", displayText, foundLine + 1))
    else
        micro.InfoBar():Message("No function found")
    end
end

-- Search for word under cursor using fzf
-- Search for word under cursor using fzf
function SearchWord(bp)
    if bp == nil then return end
    
    local buf = bp.Buf
    if buf == nil then
        micro.InfoBar():Message("No buffer")
        return
    end
    
    local cur = bp.Cursor
    if cur == nil then return end
    
    -- Get the word under cursor
    local word = getWordUnderCursor(bp)
    if word == nil or word == "" then
        micro.InfoBar():Message("No word under cursor")
        return
    end
    
    -- Get number of lines
    local numLines = buf:LinesNum()
    if numLines == 0 then
        micro.InfoBar():Message("Empty buffer")
        return
    end
    
    -- Build a temporary file with line numbers and content
    local tempFile = os.tmpname()
    local f = io.open(tempFile, "w")
    if not f then
        micro.InfoBar():Message("Failed to create temp file")
        return
    end
    
    -- Write each line that contains the word (case-insensitive)
    local found = false
    for i = 0, numLines - 1 do  -- 0-indexed lines
        local line = buf:Line(i)
        if line and line:lower():find(word:lower(), 1, true) then
            -- Format: line_number:line_content (1-indexed for display)
            f:write(string.format("%d:%s\n", i + 1, line))
            found = true
        end
    end
    f:close()
    
    if not found then
        os.remove(tempFile)
        micro.InfoBar():Message(string.format("No occurrences of '%s' found", word))
        return
    end
    
    -- Run fzf to let user select
    -- local cmd = string.format("cat '%s' | fzf --layout=reverse --prompt='%s: ' || read -p asd", tempFile, word)
    local cmd = string.format("bash -c \"cat '%s' | fzf --reverse\"", tempFile)
    
    -- local cmd = string.format("bash -c \"'%s' '%s'|fzf --layout=reverse|cut -d':' -f1\"", get_analyzer_path(), filename)
    
    local out = shell.RunInteractiveShell(cmd, false, true)
    
    -- Clean up temp file
    os.remove(tempFile)
    
    -- Process selection
    if out == nil or out == "" then
        micro.InfoBar():Message("Search cancelled")
        return
    end
    
    -- Extract line number from the selection (format: line:content)
    local lineNumStr = out:match("^(%d+):")
    if lineNumStr == nil then
        micro.InfoBar():Message("Invalid selection")
        return
    end
    
    local lineNum = tonumber(lineNumStr)
    if lineNum == nil then
        micro.InfoBar():Message("Invalid line number")
        return
    end
    
    -- Move cursor to the selected line (0-indexed)
    cur.Y = lineNum - 1
    cur.X = 0
    bp:Relocate()
    
    -- Try to find the word position on the line
    local targetLine = buf:Line(lineNum - 1)
    if targetLine then
        local startPos = targetLine:lower():find(word:lower(), 1, true)
        if startPos then
            cur.X = startPos - 1 -- 0-indexed
        end
    end
    
    micro.InfoBar():Message(string.format("Jumped to '%s' (line %d)", word, lineNum))
end

-- Helper: Get the word under the cursor
function getWordUnderCursor(bp)
    local buf = bp.Buf
    local cur = bp.Cursor
    
    local line = buf:Line(cur.Y)
    if line == nil or line == "" then
        return nil
    end
    
    local pos = cur.X + 1 -- Convert to 1-indexed for string manipulation
    
    -- Define what constitutes a word character
    local wordChars = "[%w_]"
    
    -- Check if we're on a word character
    local charAtCursor = line:sub(pos, pos)
    if not charAtCursor:match(wordChars) then
        -- Check if we're adjacent to a word
        if pos > 1 then
            local beforeChar = line:sub(pos - 1, pos - 1)
            if beforeChar:match(wordChars) then
                -- Find word that ends before cursor
                local startPos = pos - 1
                while startPos > 1 do
                    local char = line:sub(startPos - 1, startPos - 1)
                    if not char:match(wordChars) then
                        break
                    end
                    startPos = startPos - 1
                end
                return line:sub(startPos, pos - 1)
            end
        end
        if pos < #line then
            local afterChar = line:sub(pos + 1, pos + 1)
            if afterChar:match(wordChars) then
                -- Find word that starts after cursor
                local endPos = pos + 1
                while endPos < #line do
                    local char = line:sub(endPos + 1, endPos + 1)
                    if not char:match(wordChars) then
                        break
                    end
                    endPos = endPos + 1
                end
                return line:sub(pos + 1, endPos)
            end
        end
        return nil
    end
    
    -- We're on a word, expand to get full word
    local startPos = pos
    while startPos > 1 do
        local char = line:sub(startPos - 1, startPos - 1)
        if not char:match(wordChars) then
            break
        end
        startPos = startPos - 1
    end
    
    local endPos = pos
    while endPos < #line do
        local char = line:sub(endPos + 1, endPos + 1)
        if not char:match(wordChars) then
            break
        end
        endPos = endPos + 1
    end
    
    return line:sub(startPos, endPos)
end
