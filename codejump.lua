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
  
  	config.TryBindKey("F4", "command:codejump", true)
  	config.TryBindKey("Ctrl-Up", "command:defjumpup", true)
  	config.TryBindKey("Ctrl-Down", "command:defjumpdown", true)
  	config.TryBindKey("F5", "command:showcurrentfunction", true)
   
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
