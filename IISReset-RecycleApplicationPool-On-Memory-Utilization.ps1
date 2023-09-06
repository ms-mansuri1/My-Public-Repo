# Define memory threshold (90%)
$memoryThreshold = 90

# Send Email settings
$emailSettings = @{
    Username = "XYZ USERNAME"
    Password = Get-Content C:\Script\string.txt | ConvertTo-SecureString -AsPlainText -Force
    Port = 25
    SmtpServer = "XYZ.SMTP.COM"
    Recipients = @("ABC.COM", "ABC2.COM")
    From = "XYZ.COM"
}

# Function to send email notification
function Send-EmailNotification {
    param (
        [string]$subject,
        [string]$body,
        [string]$error = $null
    )

    try {
        $smtp = New-Object Net.Mail.SmtpClient($emailSettings.SmtpServer)
        $smtp.Credentials = New-Object System.Net.NetworkCredential($emailSettings.Username, $emailSettings.Password)
        $smtp.Port = $emailSettings.Port
        $message = New-Object System.Net.Mail.MailMessage

        # Get the IP address of the server
        $ipAddress = Test-Connection -ComputerName $env:COMPUTERNAME -Count 1 | Select-Object -ExpandProperty IPV4Address

        # Add IP address to the email subject
        $message.Subject = "SERVER - IP: $ipAddress - $subject"
        $message.Body = "DEAR CONCERN `r`nHostname: $($env:COMPUTERNAME)`r`nIP Address: $ipAddress`r`n$body"

        # Add recipients
        $emailSettings.Recipients | ForEach-Object { $message.To.Add($_) }

        # Add error message if provided
        if ($error) {
            $message.Body += "`r`nError Message:`r`n$error"
        }

        $message.From = $emailSettings.From
        $smtp.Send($message)
    } catch {
        Write-Host "Failed to send email: $_"
    }
}

# Function to restart IIS and recycle application pool with error handling
function Restart-IIS {
    try {
        # Recycle application pool
        Invoke-Command -ScriptBlock {
            Import-Module WebAdministration
            Restart-WebAppPool -Name "CitrussTools.WS"
        }

        # Restart IIS
        Restart-Service -Name "W3SVC" -Force

        # Check if IIS service is running
        if ((Get-Service -Name "W3SVC").Status -eq "Running") {
            return $true
        } else {
            return $false
        }
    } catch {
        # Handle error and send an error email
        $errorMessage = $_.Exception.Message
        Send-EmailNotification " IIS restart failed. Check the server for issues." $errorMessage
        return $false
    }
}

# Function to check memory utilization
function Check-MemoryUtilization {
    $totalMemory = (Get-WmiObject -Class Win32_OperatingSystem).TotalVisibleMemorySize
    $freeMemory = (Get-WmiObject -Class Win32_OperatingSystem).FreePhysicalMemory
    $usedMemoryPercentage = (($totalMemory - $freeMemory) / $totalMemory) * 100

    if ($usedMemoryPercentage -ge $memoryThreshold) {
        # If the used memory percentage is greater than or equal to 90%, take action
        $result = Restart-IIS

        if ($result -eq $true) {
            # Send success alert
            Send-EmailNotification "IIS has been restarted successfully."
        }
    }
}

# Main monitoring loop - Check only between 1 PM and 4 PM
while ($true) {
    $currentTime = Get-Date
    $startMonitoringTime = Get-Date -Hour 13 -Minute 00 -Second 0
    $endMonitoringTime = Get-Date -Hour 16 -Minute 00 -Second 0

    if ($currentTime -ge $startMonitoringTime -and $currentTime -lt $endMonitoringTime) {
        Check-MemoryUtilization
    }

    # Check every 5 minutes
    Start-Sleep -Seconds 300
}
