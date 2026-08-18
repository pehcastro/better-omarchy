.pragma library

// Omarchy's own routes, as rows. Most are menu routes summoned by name; a few
// are bar panels, which the menu does not know about and which need a different
// command. Both look the same from here.

var COMMANDS = [
  { id: "theme", title: "Change Theme", subtitle: "Appearance", glyph: "",
    keywords: ["theme", "colour", "color", "appearance", "dark", "light"],
    exec: "omarchy menu summon style.theme" },

  { id: "background", title: "Change Background", subtitle: "Appearance", glyph: "",
    keywords: ["wallpaper", "background", "desktop", "picture"],
    exec: "omarchy menu summon style.background" },

  { id: "font", title: "Change Font", subtitle: "Appearance", glyph: "",
    keywords: ["font", "typeface", "text"],
    exec: "omarchy menu summon style.font" },

  { id: "bar", title: "Bar Settings", subtitle: "Appearance", glyph: "",
    keywords: ["bar", "status", "panel", "top"],
    exec: "omarchy menu summon style.bar" },

  { id: "wifi", title: "Wi-Fi", subtitle: "Network", glyph: "",
    keywords: ["wifi", "wireless", "network", "internet"],
    exec: "omarchy-shell shell summon omarchy.network" },

  { id: "bluetooth", title: "Bluetooth", subtitle: "Network", glyph: "",
    keywords: ["bluetooth", "pair", "headphones", "device"],
    exec: "omarchy-shell shell summon omarchy.bluetooth" },

  { id: "audio", title: "Audio", subtitle: "Hardware", glyph: "",
    keywords: ["audio", "sound", "volume", "output", "microphone"],
    exec: "omarchy-shell shell summon omarchy.audio" },

  { id: "display", title: "Displays", subtitle: "Hardware", glyph: "",
    keywords: ["display", "monitor", "screen", "resolution", "brightness"],
    exec: "omarchy-shell shell summon omarchy.monitor" },

  { id: "keybindings", title: "Keybindings", subtitle: "Help", glyph: "",
    keywords: ["keys", "keybindings", "shortcuts", "bindings", "help"],
    exec: "omarchy-menu-keybindings" },

  { id: "monitors", title: "Monitor Setup", subtitle: "Settings", glyph: "",
    keywords: ["monitors", "arrange", "layout", "scaling"],
    exec: "omarchy menu summon setup.monitors" },

  { id: "input", title: "Input Setup", subtitle: "Settings", glyph: "",
    keywords: ["input", "keyboard", "mouse", "touchpad", "layout"],
    exec: "omarchy menu summon setup.input" },

  { id: "defaults", title: "Default Applications", subtitle: "Settings", glyph: "",
    keywords: ["default", "defaults", "browser", "editor", "terminal", "handler"],
    exec: "omarchy menu summon setup.default" },

  { id: "plugins", title: "Plugins", subtitle: "Settings", glyph: "",
    keywords: ["plugins", "widgets", "extensions"],
    exec: "omarchy menu summon setup.plugin" },

  { id: "install", title: "Install Software", subtitle: "Packages", glyph: "",
    keywords: ["install", "package", "software", "add", "app"],
    exec: "omarchy menu summon install" },

  { id: "remove", title: "Remove Software", subtitle: "Packages", glyph: "",
    keywords: ["remove", "uninstall", "delete", "package"],
    exec: "omarchy menu summon remove" },

  { id: "update", title: "Update Omarchy", subtitle: "System", glyph: "",
    keywords: ["update", "upgrade", "refresh", "restart"],
    exec: "omarchy menu summon update" },

  { id: "lock", title: "Lock Screen", subtitle: "Session", glyph: "",
    keywords: ["lock", "screen", "away"],
    exec: "omarchy-system-lock" },

  { id: "suspend", title: "Suspend", subtitle: "Session", glyph: "",
    keywords: ["suspend", "sleep", "standby"],
    exec: "omarchy menu summon system.suspend" },

  { id: "reboot", title: "Restart", subtitle: "Session", glyph: "",
    keywords: ["reboot", "restart"],
    exec: "omarchy menu summon system.reboot" },

  { id: "shutdown", title: "Shut Down", subtitle: "Session", glyph: "",
    keywords: ["shutdown", "power", "off", "halt"],
    exec: "omarchy menu summon system.shutdown" },

  { id: "logout", title: "Log Out", subtitle: "Session", glyph: "",
    keywords: ["logout", "log out", "sign out", "exit"],
    exec: "omarchy menu summon system.logout" },

  { id: "screenshot", title: "Screenshot", subtitle: "Capture", glyph: "",
    keywords: ["screenshot", "capture", "screen", "grab", "snip"],
    exec: "omarchy-capture-screenshot" },

  { id: "clipboard", title: "Clipboard History", subtitle: "Capture", glyph: "",
    keywords: ["clipboard", "history", "paste", "copy"],
    exec: "omarchy-shell shell toggle omarchy.clipboard" },

  { id: "emoji", title: "Emoji Picker", subtitle: "Capture", glyph: "",
    keywords: ["emoji", "emojis", "symbol", "smiley"],
    exec: "omarchy-shell shell toggle omarchy.emojis" }
]

// Shaped as a desktop entry so AppSearch.fuzzyScore can rank a command and an
// app with one function. Writing a second scorer would make the two sets mean
// different things at the same number.
function asEntry(command) {
  return {
    id: "cmd." + command.id,
    name: command.title,
    genericName: command.subtitle,
    comment: "",
    keywords: command.keywords || []
  }
}
