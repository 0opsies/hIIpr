pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell

/**
 * HyprlandConfigService
 * 
 * Handles reading, parsing, and writing Hyprland configuration.
 * Provides reactive properties for keybinds, windowrules, and layout settings.
 * 
 * Usage:
 *   - HyprlandConfigService.binds — array of {modifiers, key, dispatcher, command, description}
 *   - HyprlandConfigService.windowRules — array of windowrule strings
 *   - HyprlandConfigService.readConfig() — reload from disk
 *   - HyprlandConfigService.updateBind() — modify a keybind
 *   - HyprlandConfigService.applyConfigChanges() — write changes back to config and reload
 */
Singleton {
    id: root

    // ── Configuration paths ──
    readonly property string hyprlandConfigDir: FileUtils.trimFileProtocol(
        `${Quickshell.env("HOME")}/.config/hypr`
    )
    readonly property string hyprlandConfigPath: `${hyprlandConfigDir}/hyprland.conf`

    // ── Reactive properties ──
    property list<var> binds: []
    property list<var> windowRules: []
    property list<var> workspaceBinds: []
    
    property string currentLayout: "dwindle" // dwindle | master
    property bool layoutSupported: true

    // ── Parsing cache ──
    property var _rawConfig: ({})
    property bool _initialized: false
    property bool _isReloading: false

    // ── File watcher ──
    property var _fileWatcher: null

    /**
     * Initialize the service: read config and set up file watching.
     */
    function initialize() {
        if (_initialized) return
        _initialized = true
        readConfig()
    }

    /**
     * Read hyprland.conf from disk and parse keybinds, windowrules, etc.
     */
    function readConfig() {
        _isReloading = true
        try {
            const configContent = Quickshell.exec([
                "cat",
                hyprlandConfigPath
            ], null, true)

            if (!configContent) {
                console.warn("[HyprlandConfigService] Config file is empty or unreadable")
                _isReloading = false
                return
            }

            _rawConfig = parseConfig(configContent)
            _extractBindings()
            _extractWindowRules()
            _extractLayout()
            currentLayout = _rawConfig.layout || "dwindle"

            console.info("[HyprlandConfigService] Parsed", binds.length, "keybinds,", windowRules.length, "windowrules")
        } catch (e) {
            console.error("[HyprlandConfigService] Failed to read config:", e)
        }
        _isReloading = false
    }

    /**
     * Parse raw config string into structured data.
     * Returns object with keybinds, windowrules, layout, etc.
     */
    function parseConfig(content: string): object {
        const result = {
            binds: [],
            windowRules: [],
            layout: "dwindle",
            rawLines: []
        }

        const lines = content.split("\n")

        for (let i = 0; i < lines.length; i++) {
            let line = lines[i].trim()

            // Skip comments and empty lines
            if (line.startsWith("#") || line.length === 0) {
                result.rawLines.push(line)
                continue
            }

            // Handle line continuations (backslash at end)
            while (line.endsWith("\\") && i + 1 < lines.length) {
                line = line.slice(0, -1) + lines[++i].trim()
            }

            result.rawLines.push(line)

            // Extract bind statements: bind = MODIFIERS, KEY, DISPATCHER, COMMAND
            if (line.startsWith("bind")) {
                const bindObj = parseBindLine(line)
                if (bindObj) result.binds.push(bindObj)
            }

            // Extract windowrule statements
            if (line.startsWith("windowrule")) {
                result.windowRules.push(line)
            }

            // Extract general:layout setting
            if (line.includes("general:layout")) {
                const match = line.match(/general:layout\s*=\s*(\w+)/)
                if (match) result.layout = match[1].toLowerCase()
            }
        }

        return result
    }

    /**
     * Parse a single bind line into structured object.
     * Format: bind[l|r] = MODIFIERS, KEY, DISPATCHER, [COMMAND]
     * Examples:
     *   bind = SUPER, E, exec, kitty
     *   bind = SUPER SHIFT, Return, exec, firefox
     *   bind = SUPER, Tab, workspace, next
     */
    function parseBindLine(line: string): object | null {
        // Match: bind[lr]? = MODS, KEY, DISP, CMD
        const regex = /^bind([lr])?\ *= \s*(.+?)\s*,\s*(.+?)\s*,\s*(.+?)\s*,\s*(.*)$/
        const match = line.match(regex)

        if (!match) {
            console.warn("[HyprlandConfigService] Could not parse bind line:", line)
            return null
        }

        const [, bindType, modifiers, key, dispatcher, command] = match

        return {
            line: line,
            bindType: bindType || "", // "l", "r", or empty
            modifiers: modifiers.trim(),
            key: key.trim().toUpperCase(),
            dispatcher: dispatcher.trim(),
            command: command.trim(),
            description: _getBindDescription(dispatcher, command)
        }
    }

    /**
     * Generate a human-readable description from dispatcher + command.
     */
    function _getBindDescription(dispatcher: string, command: string): string {
        const d = dispatcher.toLowerCase()

        if (d === "exec" || d === "execr") return `Execute: ${command}`
        if (d === "workspace") return `Switch workspace: ${command}`
        if (d === "movetoworkspace") return `Move to workspace: ${command}`
        if (d === "togglefloating") return "Toggle floating"
        if (d === "togglesplit") return "Toggle split"
        if (d === "killactive") return "Close window"
        if (d === "fullscreen") return "Fullscreen"

        return `${dispatcher}: ${command}`.slice(0, 50)
    }

    /**
     * Extract binds from parsed config.
     */
    function _extractBindings() {
        const extracted = []
        if (_rawConfig.binds && Array.isArray(_rawConfig.binds)) {
            for (const bind of _rawConfig.binds) {
                extracted.push(bind)
            }
        }
        binds = extracted
    }

    /**
     * Extract windowrules from parsed config.
     */
    function _extractWindowRules() {
        const extracted = []
        if (_rawConfig.windowRules && Array.isArray(_rawConfig.windowRules)) {
            for (const rule of _rawConfig.windowRules) {
                extracted.push(rule)
            }
        }
        windowRules = extracted
    }

    /**
     * Extract layout from parsed config.
     */
    function _extractLayout() {
        currentLayout = (_rawConfig.layout || "dwindle").toLowerCase()
    }

    /**
     * Update a keybind in memory.
     * Does NOT write to disk or reload Hyprland yet.
     */
    function updateBind(index: int, updatedBind: object): void {
        if (index < 0 || index >= binds.length) return

        const newBinds = [...binds]
        newBinds[index] = {
            ...newBinds[index],
            ...updatedBind
        }

        // Regenerate line
        newBinds[index].line = reconstructBindLine(newBinds[index])

        binds = newBinds
        console.info("[HyprlandConfigService] Updated bind at index", index)
    }

    /**
     * Add a new keybind.
     */
    function addBind(modifiers: string, key: string, dispatcher: string, command: string): void {
        const newBind = {
            bindType: "",
            modifiers: modifiers.toUpperCase(),
            key: key.toUpperCase(),
            dispatcher: dispatcher.toLowerCase(),
            command: command,
            description: _getBindDescription(dispatcher, command),
            line: ""
        }

        newBind.line = reconstructBindLine(newBind)
        binds = [...binds, newBind]
        console.info("[HyprlandConfigService] Added new bind:", newBind.key)
    }

    /**
     * Remove a keybind.
     */
    function removeBind(index: int): void {
        if (index < 0 || index >= binds.length) return
        const newBinds = binds.filter((_, i) => i !== index)
        binds = newBinds
        console.info("[HyprlandConfigService] Removed bind at index", index)
    }

    /**
     * Reconstruct a bind line from a bind object.
     */
    function reconstructBindLine(bind: object): string {
        const type = bind.bindType ? bind.bindType : ""
        return `bind${type} = ${bind.modifiers}, ${bind.key}, ${bind.dispatcher}, ${bind.command}`
    }

    /**
     * Write all changes back to hyprland.conf and reload.
     */
    function applyConfigChanges(): bool {
        try {
            // Rebuild config content
            let newContent = ""
            let bindIndex = 0
            let ruleIndex = 0

            // Reconstruct line by line, replacing modified binds/rules
            for (const line of _rawConfig.rawLines) {
                if (line.startsWith("bind")) {
                    if (bindIndex < binds.length) {
                        newContent += binds[bindIndex].line + "\n"
                        bindIndex++
                    }
                } else if (line.startsWith("windowrule")) {
                    if (ruleIndex < windowRules.length) {
                        newContent += windowRules[ruleIndex] + "\n"
                        ruleIndex++
                    }
                } else {
                    newContent += line + "\n"
                }
            }

            // Add any new binds that weren't in original config
            while (bindIndex < binds.length) {
                newContent += binds[bindIndex].line + "\n"
                bindIndex++
            }

            // Write to file
            const tempFile = `${hyprlandConfigDir}/.hyprland.conf.tmp`
            const writeResult = Quickshell.exec([
                "tee",
                tempFile
            ], newContent, true)

            // Move temp file to actual config
            Quickshell.exec(["mv", tempFile, hyprlandConfigPath], null, true)

            console.info("[HyprlandConfigService] Config written to disk")

            // Reload Hyprland
            return reloadHyprland()
        } catch (e) {
            console.error("[HyprlandConfigService] Failed to apply changes:", e)
            return false
        }
    }

    /**
     * Reload Hyprland configuration.
     */
    function reloadHyprland(): bool {
        try {
            Quickshell.exec(["hyprctl", "reload"], null, true)
            console.info("[HyprlandConfigService] Hyprland reloaded")
            return true
        } catch (e) {
            console.error("[HyprlandConfigService] Failed to reload Hyprland:", e)
            return false
        }
    }

    /**
     * Switch to a different layout (dwindle or master).
     */
    function switchLayout(layout: string): void {
        const validLayouts = ["dwindle", "master"]
        const normalizedLayout = layout.toLowerCase()

        if (!validLayouts.includes(normalizedLayout)) {
            console.warn("[HyprlandConfigService] Invalid layout:", layout)
            return
        }

        try {
            Quickshell.exec([
                "hyprctl",
                "keyword",
                "general:layout",
                normalizedLayout
            ], null, true)

            currentLayout = normalizedLayout
            console.info("[HyprlandConfigService] Layout switched to:", normalizedLayout)
        } catch (e) {
            console.error("[HyprlandConfigService] Failed to switch layout:", e)
        }
    }

    // ── Lifecycle ──
    Component.onCompleted: {
        initialize()
    }
}
