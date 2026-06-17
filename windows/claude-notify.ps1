param(
  [string]$Title   = "Claude Code",
  [string]$Message  = "",
  [string]$ToastTag = "claude-code"
)
$ErrorActionPreference = "Stop"

# Native Windows 10/11 toast via WinRT — no modules to install.
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null
[Windows.UI.Notifications.ToastNotification,        Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument,                  Windows.Data.Xml.Dom.XmlDocument, ContentType=WindowsRuntime] | Out-Null

# Build the toast XML via DOM so text is safely escaped (no string interpolation).
$doc = New-Object Windows.Data.Xml.Dom.XmlDocument
$toastXml =
@'
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text id="1"></text>
      <text id="2"></text>
    </binding>
  </visual>
</toast>
'@
$doc.LoadXml($toastXml)

$texts = $doc.GetElementsByTagName("text")
$texts.Item(0).AppendChild($doc.CreateTextNode($Title))   | Out-Null
$texts.Item(1).AppendChild($doc.CreateTextNode($Message)) | Out-Null

$toast = New-Object Windows.UI.Notifications.ToastNotification $doc
$toast.Tag = $ToastTag        # same tag => new toast replaces the old, no spam

# Use the built-in PowerShell AppUserModelID so Windows lets the toast through.
$appId = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
