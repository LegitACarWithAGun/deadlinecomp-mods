--!strict

-- Command Reference module
-- prints a quick reference of frequently used comp commands to the server console
-- usage: run ;cmds in chat, or call print_command_reference() directly

-- load command bot
if not shared.dlcomp_command_bot then
    require("https://raw.githubusercontent.com/legitacarwithagun/deadlinecomp-mods/refs/heads/main/command-bot.luau")
end

-- keep every printed line comfortably under console/chat wrap limits
local MAX_LINE_LENGTH = 100

type reference_entry = { label: string, command: string }
type reference_section = { header: string, entries: { reference_entry } }

local COMMAND_REFERENCE: { reference_section } = {
    {
        header = "STARTING COMP MATCHES",
        entries = {
            { label = "Office",   command = [[shared.dlcomp_command_bot.run("round test_office koth")]] },
            { label = "Complex",  command = [[shared.dlcomp_command_bot.run("round test_complex koth")]] },
            { label = "Downtown", command = [[shared.dlcomp_command_bot.run("round test_downtown_v2 koth")]] },
        },
    },
    {
        header = "FREECAM",
        entries = {
            { label = "Enable freecam for self",         command = [[shared.dlcomp_command_bot.run("cam Freecam")]] },
            { label = "Enable freecam for other players", command = [[shared.dlcomp_command_bot.run("cam Freecam bachancuc123")]] },
            { label = "Get out of freecam",              command = [[shared.dlcomp_command_bot.run("cam")]] },
            { label = "Get other players out of freecam", command = [[shared.dlcomp_command_bot.run("cam . bachancuc123")]] },
        },
    },
    {
        header = "TEAMS",
        entries = {
            { label = "Scramble teams", command = [[shared.dlcomp_command_bot.run("team_scramble")]] },
            { label = "Swap teams",     command = [[shared.dlcomp_command_bot.run("team_swap")]] },
        },
    },
}

-- prints a single label/command pair, splitting onto its own line if the
-- combined line would exceed MAX_LINE_LENGTH instead of letting it wrap/error
local function print_entry(label: string, command: string, label_width: number)
    local line = string.format("%-" .. label_width .. "s : %s", label, command)

    if #line <= MAX_LINE_LENGTH then
        print(line)
        return
    end

    -- too long to fit on one line, split label and command across two
    print(string.format("%-" .. label_width .. "s :", label))
    print(string.rep(" ", 4) .. command)
end

function print_command_reference()
    for _, section in COMMAND_REFERENCE do
        print(`-- {section.header} --`)

        -- align commands to the widest label in this section
        local label_width = 0
        for _, entry in section.entries do
            label_width = math.max(label_width, #entry.label)
        end

        for _, entry in section.entries do
            print_entry(entry.label, entry.command, label_width)
        end

        print("")
    end
end

shared.dlcomp_command_bot.add_command("cmds", "prints a quick reference of frequently used comp commands to the server console", function()
    print_command_reference()
    return "printed command reference to server console"
end)

shared.dlcomp_command_reference = {
    print_command_reference = print_command_reference,
}
