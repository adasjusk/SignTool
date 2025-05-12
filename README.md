# First Steps
1. Install [Visual Studio Community Edition](https://visualstudio.microsoft.com/downloads/)
2. During installation, select the ".NET desktop development" workload (you can add others later).
3. Finish installation.

# Use the Signing Tool to Create a Certificate
0. Launch Powershell by pressing Win + X and pressing Terminal (admin) or Win Powershell (admin)
1. Launch the Signing Tool from this:
```
irm https://raw.githubusercontent.com/adasjusk/SignTool/main/SignTool.ps1 | iex
```
2. Switch to the Create Certificate tab.
3. Press Create Certificate button
4. It will generate a .pfx file.

# Sign a .exe File Using the Tool
1. Go to the Sign Executable tab.
3. Click Browse… next find Executable and select the .exe file you want to sign.
4. Click Sign.
5. The Status box will confirm whether the signing succeeded.

📝 This certificate is self-signed and best used for testing or internal tools. For production, use a certificate from a trusted Certificate Authority (CA).

Thanks For Support
Release date: 2025-05-12
<p align="center">Made with Love ❤️</p>
