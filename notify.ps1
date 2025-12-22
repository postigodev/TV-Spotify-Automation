param(
    [string]$Title = "TV Spotify Automation",
    [string]$Message = "An error occurred."
)

# Native Windows toast via COM
$AppId = "TVSpotifyAutomation"

$Template = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>$Title</text>
      <text>$Message</text>
    </binding>
  </visual>
</toast>
"@

$Xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$Xml.LoadXml($Template)

$Toast = [Windows.UI.Notifications.ToastNotification]::new($Xml)
$Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId)
$Notifier.Show($Toast)
