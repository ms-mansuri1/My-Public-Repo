# Define memory threshold (90%)
$memoryThreshold = 90

# Send Email settings
$username = "EMAIL-USERNAME"
$password = Get-Content PATH TO PASSWORD FILE | ConvertTo-SecureString -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password
$portno = "PORT-NO"
$smtpsrv = "SERVER-SMTP"
$smtpto = "RECIPIENT-MAIL-ADDRESS", "RECIPIENT-EMAIL-ADDRESS"
$smtpfrom = "SENDER-EMAIL-ADDRESS"

# Function to send email notification with error message
function Send-EmailNotification($subject, $body, $error = $null) {
    try {
        $smtp = New-Object Net.Mail.SmtpClient($smtpsrv)
        $smtp.Credentials = $cred
        $smtp.Port = $portno
        $message = New-Object System.Net.Mail.MailMessage
        $message.Subject = $subject
        $message.Body = $body
        $message.From = $smtpfrom
        $message.To.Add($smtpto)

        # Add error message if provided
        if ($error) {
            $message.Body += "`r`nError Message:`r`n$error"
        }

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
            Restart-WebAppPool -Name "IIS-APP-NAME"
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
        Send-EmailNotification "(HOSTNAME/IP) IIS Restart Failed" "IIS restart failed. Check the server for issues." $errorMessage
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
            Send-EmailNotification "(HOSTNAME/IP) IIS Restarted Successfully" "IIS has been restarted successfully."
        } else {
            # Send failure alert with error message
            Send-EmailNotification "(HOSTNAME/IP) IIS Restart Failed" "IIS restart failed. Check the server for issues."
        }
    }
}

# Main monitoring loop - Check only between 1 PM and 4 PM
while ($true) {
    $currentTime = Get-Date
    $startMonitoringTime = Get-Date -Hour 13 -Minute 0 -Second 0
    $endMonitoringTime = Get-Date -Hour 16 -Minute 0 -Second 0

    if ($currentTime -ge $startMonitoringTime -and $currentTime -lt $endMonitoringTime) {
        Check-MemoryUtilization
    }

    # Check every 5 minutes
    Start-Sleep -Seconds 300
}