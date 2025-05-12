Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# XAML for the GUI
[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Signing Tool" Height="400" Width="600"
    WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <StackPanel Grid.Row="0" Margin="0,0,0,10">
            <TextBlock Text="Signing Tool" FontSize="24" FontWeight="Bold" Margin="0,0,0,10"/>
            <Separator/>
        </StackPanel>

        <!-- Main Content -->
        <TabControl Grid.Row="1" Margin="0,10">
            <!-- Sign Tab -->
            <TabItem Header="Sign Executable">
                <Grid Margin="10">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <GroupBox Header="Certificate" Grid.Row="0" Margin="0,0,0,10">
                        <StackPanel Margin="5">
                            <TextBlock Text="Using certificate:" Margin="0,0,0,5"/>
                            <TextBox Name="txtCertPath" IsReadOnly="True" Margin="0,0,0,5"/>
                        </StackPanel>
                    </GroupBox>

                    <GroupBox Header="Executable" Grid.Row="1" Margin="0,0,0,10">
                        <Grid Margin="5">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBox Name="txtExePath" Grid.Column="0" Margin="0,0,5,0"/>
                            <Button Name="btnBrowseExe" Content="Browse..." Grid.Column="1" Width="80"/>
                        </Grid>
                    </GroupBox>

                    <GroupBox Header="Status" Grid.Row="2">
                        <TextBox Name="txtLog" IsReadOnly="True" TextWrapping="Wrap" 
                                VerticalScrollBarVisibility="Auto" Margin="5"/>
                    </GroupBox>
                </Grid>
            </TabItem>

            <!-- Create Certificate Tab -->
            <TabItem Header="Create Certificate">
                <Grid Margin="10">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <StackPanel Grid.Row="0">
                        <TextBlock TextWrapping="Wrap" Margin="0,0,0,10">
                            This will create a new self-signed certificate for code signing. 
                            The certificate will be valid for 5 years.
                        </TextBlock>
                        <Button Name="btnCreateCert" Content="Create Certificate" 
                                HorizontalAlignment="Left" Padding="20,5"/>
                    </StackPanel>

                    <GroupBox Header="Status" Grid.Row="1" Margin="0,10,0,0">
                        <TextBox Name="txtCertLog" IsReadOnly="True" TextWrapping="Wrap" 
                                VerticalScrollBarVisibility="Auto" Margin="5"/>
                    </GroupBox>
                </Grid>
            </TabItem>
        </TabControl>

        <!-- Footer -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button Name="btnSign" Content="Sign" Width="80" Margin="0,0,10,0"/>
            <Button Name="btnClose" Content="Close" Width="80"/>
        </StackPanel>
    </Grid>
</Window>
"@

# Create the window
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$controls = @{}
$xaml.SelectNodes("//*[@Name]") | ForEach-Object {
    $controls[$_.Name] = $window.FindName($_.Name)
}

# Script variables
$script:certPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "cert.pfx"
$script:certPassword = "Adasjusk2025"

# Update certificate path textbox
$controls.txtCertPath.Text = $script:certPath

# Helper function to write to log
function Write-Log {
    param($Message, $LogBox)
    $controls.$LogBox.AppendText("$Message`n")
    $controls.$LogBox.ScrollToEnd()
}

# Browse for executable
$controls.btnBrowseExe.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "Executable files (*.exe)|*.exe|All files (*.*)|*.*"
    if ($dialog.ShowDialog() -eq 'OK') {
        $controls.txtExePath.Text = $dialog.FileName
    }
})

# Create certificate
$controls.btnCreateCert.Add_Click({
    try {
        Write-Log "Creating new certificate..." "txtCertLog"
          $cert = New-SelfSignedCertificate `
            -Subject "CN=InterJava Projects" `
            -KeyUsage DigitalSignature `
            -KeySpec Signature `
            -KeyLength 2048 `
            -HashAlgorithm SHA256 `
            -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" `
            -Type CodeSigningCert `
            -NotAfter (Get-Date).AddYears(5) `
            -CertStoreLocation "Cert:\CurrentUser\My"

        Write-Log "Exporting certificate to $script:certPath" "txtCertLog"
        
        $securePassword = ConvertTo-SecureString -String $script:certPassword -AsPlainText -Force
        $cert | Export-PfxCertificate -FilePath $script:certPath -Password $securePassword
        
        if (Test-Path $script:certPath) {
            Write-Log "Certificate created successfully!" "txtCertLog"
            $controls.txtCertPath.Text = $script:certPath
        } else {
            throw "Failed to create certificate file"
        }
    } catch {
        Write-Log "Error: $_" "txtCertLog"
    }
})

# Sign executable
$controls.btnSign.Add_Click({
    if (-not $controls.txtExePath.Text) {
        [System.Windows.MessageBox]::Show("Please select an executable to sign.", "Error", "OK", "Error")
        return
    }

    if (-not (Test-Path $script:certPath)) {
        [System.Windows.MessageBox]::Show("Certificate not found. Please create a certificate first.", "Error", "OK", "Error")
        return
    }

    try {
        Write-Log "Starting signing process..." "txtLog"
        
        # Try to find signtool.exe
        $signToolPaths = @(
            "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\signtool.exe",
            "C:\Program Files (x86)\Windows Kits\10\App Certification Kit\signtool.exe",
            "C:\Program Files\Microsoft SDKs\Windows\v*\bin\signtool.exe"
        )

        $signTool = Get-ChildItem -Path $signToolPaths -ErrorAction SilentlyContinue | 
            Sort-Object -Property VersionInfo.ProductVersion -Descending |
            Select-Object -First 1 -ExpandProperty FullName

        if (-not $signTool) {
            throw "signtool.exe not found. Please install Windows SDK."
        }        Write-Log "Using signtool: $signTool" "txtLog"
        Write-Log "Signing $($controls.txtExePath.Text)..." "txtLog"

        $arguments = @(
            "sign",
            "/f", $script:certPath,
            "/p", $script:certPassword,
            "/fd", "sha256",
            "/tr", "http://timestamp.digicert.com",
            "/td", "sha256",
            $controls.txtExePath.Text
        )
        
        $process = Start-Process -FilePath $signTool -ArgumentList $arguments -NoNewWindow -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            Write-Log "File signed successfully!" "txtLog"
            [System.Windows.MessageBox]::Show("File signed successfully!", "Success", "OK", "Information")
        } else {
            throw "Signing failed with exit code: $($process.ExitCode)"
        }
    } catch {
        Write-Log "Error: $_" "txtLog"
        [System.Windows.MessageBox]::Show("Error: $_", "Error", "OK", "Error")
    }
})

# Close button
$controls.btnClose.Add_Click({ $window.Close() })

# Show the window
$window.ShowDialog() | Out-Null
