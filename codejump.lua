VERSION = "1.0.0"

-- a plugin to navigate through functions/classes
-- codejump: uses fzf to display a list of all functions and choose from
-- defjumpdown: finds the next function from the current position
-- defjumpup: fund the previous function from the current position
-- made by XQTR // cp737.net

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
  
  config.TryBindKey("F4", "command:codejump", true)
  config.TryBindKey("Ctrl-Up", "command:defjumpup", true)
  config.TryBindKey("Ctrl-Down", "command:defjumpdown", true)
   
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
