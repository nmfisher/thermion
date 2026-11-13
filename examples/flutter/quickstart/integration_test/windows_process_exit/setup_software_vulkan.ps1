param(
    [Parameter(Mandatory = $true)]
    [string]$BundleDirectory
)

$ErrorActionPreference = 'Stop'
$bundle = (New-Item -ItemType Directory -Force $BundleDirectory).FullName
$download = Join-Path $env:RUNNER_TEMP 'thermion-software-vulkan'
New-Item -ItemType Directory -Force $download | Out-Null

# Pin both packages so driver updates do not silently change the test setup.
$mesa = Join-Path $download 'mesa.7z'
Invoke-WebRequest 'https://github.com/pal1000/mesa-dist-win/releases/download/26.2.5/mesa3d-26.2.5-release-msvc.7z' -OutFile $mesa
if ((Get-FileHash $mesa -Algorithm SHA256).Hash -ne '997123EF4CE8896204AB912D5B54F19372C487FF9835BCEFAFA2FCA23B8953C2') {
    throw 'Mesa package checksum mismatch'
}
& 7z x $mesa "-o$download/mesa" -y x64/vulkan_dzn.dll x64/dxil.dll x64/dzn_icd.x86_64.json
if ($LASTEXITCODE -ne 0) { throw 'Mesa extraction failed' }
# Do not deploy Mesa's d3d10warp.dll: use Windows' own WARP implementation.
Copy-Item "$download/mesa/x64/vulkan_dzn.dll", "$download/mesa/x64/dxil.dll", "$download/mesa/x64/dzn_icd.x86_64.json" $bundle

$runtime = Join-Path $download 'vulkan-runtime.zip'
Invoke-WebRequest 'https://sdk.lunarg.com/sdk/download/1.4.363.0/windows/VulkanRT-X64-1.4.363.0-Components.zip' -OutFile $runtime
if ((Get-FileHash $runtime -Algorithm SHA256).Hash -ne 'A25A927AA8B9F0371048F1861CF88AC3B9BC9B1FB332C42D897C8AB32695769A') {
    throw 'Vulkan runtime checksum mismatch'
}
Expand-Archive $runtime -DestinationPath "$download/runtime" -Force
$runtimeX64 = "$download/runtime/VulkanRT-X64-1.4.363.0-Components/x64"
Copy-Item "$runtimeX64/vulkan-1.dll", "$runtimeX64/vulkaninfo.exe" $bundle

$env:VK_DRIVER_FILES = Join-Path $bundle 'dzn_icd.x86_64.json'
$env:DZN_DEBUG = 'warp'
# Elevated Windows processes ignore driver-path environment overrides. GitHub's
# runner is elevated, so install this ICD through the normal discovery key.
$driversKey = 'HKLM:\SOFTWARE\Khronos\Vulkan\Drivers'
New-Item $driversKey -Force | Out-Null
New-ItemProperty $driversKey -Name $env:VK_DRIVER_FILES -PropertyType DWord -Value 0 -Force | Out-Null
"VK_DRIVER_FILES=$env:VK_DRIVER_FILES" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
'DZN_DEBUG=warp' | Out-File $env:GITHUB_ENV -Append -Encoding utf8
& "$bundle/vulkaninfo.exe" --summary
if ($LASTEXITCODE -ne 0) { throw 'Software Vulkan initialization failed' }
