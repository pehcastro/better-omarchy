# PreToolUse hook. It blocks a Write or an Edit whose input holds an em dash (U+2014).
#
# Read the standard input as UTF-8 explicitly. The default console encoding on Windows is
# the system codepage, which decodes the three UTF-8 bytes of an em dash as three separate
# characters. The match then never happens and the hook passes everything.
$reader = [System.IO.StreamReader]::new([Console]::OpenStandardInput(), [System.Text.Encoding]::UTF8)
$stdin = $reader.ReadToEnd()

$emdash = [char]0x2014

if ($stdin.IndexOf($emdash) -ge 0) {
    [Console]::Error.WriteLine("BLOCKED: an em dash (U+2014) is forbidden in this repository. Use a comma, a colon, a period, parentheses, or a plain hyphen.")
    exit 2
}

exit 0
