﻿$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
$VerbosePreference = 'Continue'

$msDeployOnTargetMachinesPath = "$currentScriptPath\..\..\..\src\Tasks\IISWebAppDeploy\$sut"

if(-not (Test-Path -Path $msDeployOnTargetMachinesPath ))
{
    throw [System.IO.FileNotFoundException] "Unable to find MsDeployOnTargetMachines.ps1 at $msDeployOnTargetMachinesDirectoryPath"
}

. "$msDeployOnTargetMachinesPath"

Describe "Tests for verifying Run-Command functionality"{

    Context "When command execution fails" {

        $errMsg = "Command Execution Failed"
        Mock cmd.exe { throw $errMsg}
        
        try
        {
            $result = Run-Command -command "NonExisingCommand"
        }
        catch
        {
            $result = $_
        }
        
        It "should throw exception" {
            ($result.Exception.ToString().Contains("$errMsg")) | Should Be $true
        }
    }

    Context "When command execution successful" {
            
        try
        {
            $result = Run-Command -command "echo %cd%"
        }
        catch
        {
            $result = $_
        }
        
        It "should not throw exception" {
            $result.Exception | Should Be $null
        }
    }
}

Describe "Tests for verifying Get-MsDeployLocation functionality" {

    $msDeployNotFoundError = "Cannot find MsDeploy.exe location. Verify MsDeploy.exe is installed on $env:ComputeName and try operation again."
    Context "Get-ChildItem for fetching MsDeploy location, returns non-existing path" {

        $regKeyWithNoInstallPath = "HKLM:\SOFTWARE\Microsoft"
                
        It "Should throw exception" {
            { Get-MsDeployLocation -regKeyPath $regKeyWithNoInstallPath } | Should Throw
        }
    }

    Context "Get-ChildItem for fails as MsDeploy not installed on the machine" {
            
        $inValidInstallPathRegKey = "HKLM:\SOFTWARE\Microsoft\IIS Extensions\Invalid"

        It "Should throw exception" {
            { Get-MsDeployLocation -regKeyPath $inValidInstallPathRegKey } | Should Throw $msDeployNotFoundError
        }
    }
}

Describe "Tests for verifying Get-AppCmdLocation functionality" {

    $appCmdNotFoundError = "Cannot find appcmd.exe location. Verify IIS is configured on $env:ComputerName and try operation again."
    $appCmdMinVersionError = "Version of IIS is less than 7.0 on machine $env:ComputerName. Minimum version of IIS required is 7.0"

    Context "Get-ItemProperty for MajorVersion returns version 6" {

        $regKeyWithNoInstallPath = "HKLM:\SOFTWARE\Microsoft"
        $regKey = @{ MajorVersion = "6" 
                     InstallPath = "$env:SystemDrive"}
        Mock Get-ItemProperty { return $regKey } -ParameterFilter { $Path -eq $regKeyWithNoInstallPath }
        
        It "Should throw task not supported exception" {
            { Get-AppCmdLocation -regKeyPath $regKeyWithNoInstallPath } | Should Throw $appCmdMinVersionError
        }
    }

    Context "Get-ItemProperty for InstallPath returns non-existing path" {

        $regKeyWithNoInstallPath = "HKLM:\SOFTWARE\Microsoft"
        $regKey = @{ MajorVersion = "7" 
                     InstallPath = "xyz:"}        
        Mock Get-ItemProperty { return $regKey } -ParameterFilter { $Path -eq $regKeyWithNoInstallPath }

        It "Should throw appcmd not installed exception" {
            { Get-AppCmdLocation -regKeyPath $regKeyWithNoInstallPath } | Should Throw $appCmdNotFoundError
        }
    }

    Context "Get-ItemProperty for given path throws exception as the reg path does not exist" {

        $regKeyWithNoInstallPath = "HKLM:\SOFTWARE\Microsoft\Invalid"        
        
        It "Should throw exception" {
            { Get-AppCmdLocation -regKeyPath $regKeyWithNoInstallPath } | Should Throw $appCmdNotFoundError
        }
    }

    Context "Get-ItemProperty for InstallPath and MajorVersion returns proper values" {

        $regKeyWithNoInstallPath = "HKLM:\SOFTWARE\Microsoft"
        $regKey = @{ MajorVersion = "7" 
                     InstallPath = "$env:SystemDrive"}
        Mock Get-ItemProperty { return $regKey } -ParameterFilter { $Path -eq $regKeyWithNoInstallPath }
        
        $appCmdPath, $version = Get-AppCmdLocation -regKeyPath $regKeyWithNoInstallPath

        It "Should not throw exception"{
            $appCmdPath | Should Be "$env:SystemDrive\appcmd.exe"
            $version | Should Be 7
        }
    }
}

Describe "Tests for verifying Get-MsDeployCmdArgs functionality" {

    $webDeployPackage = "WebAppPackage.zip"
    $webDeployParamFile = "webDeployParamFile.xml"
    $overRideParams = "Param=Value"

    Context "When webdeploy package input only provided" {

        Mock Test-Path { return $true }

        $result = Get-MsDeployCmdArgs -webDeployPackage $webDeployPackage

        It "msDeployCmdArgs should only contain -source:packge"{
            ( $result.Contains([string]::Format('-source:package="{0}"', $webDeployPackage) ) ) | Should Be $true
            ( $result.Contains([string]::Format('-setParamFile="{0}"', $webDeployParamFile) ) )| Should Be $false
            ( $result.Contains("-setParam:$overRideParams") ) | Should Be $false
        }
    }

    Context "When webdeploy and setParamFiles input only provided" {

        Mock Test-Path { return $true }

        $result = Get-MsDeployCmdArgs -webDeployPackage $webDeployPackage -webDeployParamFile $webDeployParamFile

        It "msDeployCmdArgs should only contain -source:packge and -setParamFile" {
            ( $result.Contains([string]::Format('-source:package="{0}"', $webDeployPackage) ) ) | Should Be $true
            ( $result.Contains([string]::Format('-setParamFile="{0}"', $webDeployParamFile) ) )| Should Be $true
            ( $result.Contains("-setParam:$overRideParams") ) | Should Be $false
        }
    }

    Context "When all three inputs are provided" {

        Mock Test-Path { return $true }

        $result = Get-MsDeployCmdArgs -webDeployPackage $webDeployPackage -webDeployParamFile $webDeployParamFile -overRideParams $overRideParams
        
        It "msDeployCmdArgs should contain -source:packge, -setParamFile and -setParam" {
            ( $result.Contains([string]::Format('-source:package="{0}"', $webDeployPackage) ) ) | Should Be $true
            ( $result.Contains([string]::Format('-setParamFile="{0}"', $webDeployParamFile) ) )| Should Be $true
            ( $result.Contains("-setParam:$overRideParams") ) | Should Be $true
        }
    }

    Context "When webDeploy package does not exist" {

        $InvalidPkg = "n:\Invalid\pkg.zip"
        $errMsg = "Package does not exist : `"$InvalidPkg`""

        It "Should throw exception"{
            { Get-MsDeployCmdArgs -webDeployPackage $InvalidPkg -webDeployParamFile $webDeployParamFile -overRideParams $overRideParams } | Should Throw $errMsg
        }        
    }

    Context "When setParamFile does not exist" {

        Mock Test-Path { return $true } -ParameterFilter { $Path -eq $webDeployPackage }
        $InvalidParamFile = "n:\Invalid\param.xml"
        $errMsg = "Param file does not exist : `"$InvalidParamFile`""

        It "Should throw exception"{
            { Get-MsDeployCmdArgs -webDeployPackage $webDeployPackage -webDeployParamFile $InvalidParamFile -overRideParams $overRideParams } | Should Throw $errMsg
        }
    }

    Context "When two override params is given" {

        $param1 = "name1=value1"
        $param2 = "name2=value2"

        $params = $param1 + [System.Environment]::NewLine + $param2

        Mock Test-Path { return $true }

        $result = Get-MsDeployCmdArgs -webDeployPackage $webDeployPackage -webDeployParamFile $webDeployParamFile -overRideParams $params
        
        It "msDeployCmdArgs should contain -source:packge, -setParamFile and -setParam for each override param" {
            ( $result.Contains([string]::Format('-source:package="{0}"', $webDeployPackage) ) ) | Should Be $true
            ( $result.Contains([string]::Format('-setParamFile="{0}"', $webDeployParamFile) ) )| Should Be $true
            ( $result.Contains("-setParam:$param1") ) | Should Be $true
            ( $result.Contains("-setParam:$param2") ) | Should Be $true
        }
    }

    Context "When two override params with an empty line in between is given" {

        $param1 = "name1=value1"
        $param2 = " "
        $param3 = "name2=value2"

        $params = $param1 + [System.Environment]::NewLine + $param2 + [System.Environment]::NewLine + $param3

        Mock Test-Path { return $true }

        $result = Get-MsDeployCmdArgs -webDeployPackage $webDeployPackage -webDeployParamFile $webDeployParamFile -overRideParams $params

        It "msDeployCmdArgs should contain -source:packge, -setParamFile and -setParam for each override param"{
            ( $result.Contains([string]::Format('-source:package="{0}"', $webDeployPackage) ) ) | Should Be $true
            ( $result.Contains([string]::Format('-setParamFile="{0}"', $webDeployParamFile) ) )| Should Be $true
            ( $result.Contains("-setParam:$param1") ) | Should Be $true
            ( $result.Contains("-setParam:$param2") ) | Should Be $false
            ( $result.Contains("-setParam:$param3") ) | Should Be $true
        }
    }

    Context "When two override params with an new line in between is given"{

        $param1 = " name1=value1"
        $param2 = "name2=value2"

        $params = $param1 + [System.Environment]::NewLine + [System.Environment]::NewLine + [System.Environment]::NewLine + $param2

        Mock Test-Path { return $true }

        $result = Get-MsDeployCmdArgs -webDeployPackage $webDeployPackage -webDeployParamFile $webDeployParamFile -overRideParams $params
        
        It "msDeployCmdArgs should contain -source:packge, -setParamFile and -setParam for each override param"{
            ( $result.Contains([string]::Format('-source:package="{0}"', $webDeployPackage) ) ) | Should Be $true
            ( $result.Contains([string]::Format('-setParamFile="{0}"', $webDeployParamFile) ) )| Should Be $true
            ( $result.Contains([string]::Format("-setParam:{0}", $param1.Trim()))) | Should Be $true
            ( $result.Contains("-setParam:$param2") ) | Should Be $true
            ( $result.Contains([string]::Format('-setParam:{0}', [System.Environment]::NewLine) ) )| Should Be $false
        }
    }
}

Describe "Tests for verifying Does-WebSiteExists functionality" {

    Mock Get-AppCmdLocation {return "appcmd.exe", 8}

    Context "List WebSite command returns null." {

        Mock Run-command { return $null } -ParameterFilter { $failOnErr -eq $false }

        $result = Does-WebSiteExists -siteName "SampleWeb"
        
        It "function should return false" {
           $result | Should Be $false
        }
    }

    Context "List WebSite command returns non-null" {

        Mock Run-command { return "" } -ParameterFilter { $failOnErr -eq $false }
        
        $result = Does-WebSiteExists -siteName "SampleWeb"

        It "function should return true" {
            $result | Should Be $true
        }
    }
}

Describe "Tests for verifying Does-BindingExists functionality" {

    $protocal = "http"
    $ipAddress = "*"
    $port = "80"
    $hostname = ""
    $binding1 = [string]::Format("{0}/{1}:{2}:{3}", $protocal, $ipAddress, $port, $hostname)
    $binding2 = [string]::Format("{0}/{1}:{2}:{3}", $protocal, $ipAddress, "8080", "localhost")

    Mock Get-AppCmdLocation { return "appcmd.exe", 8 }
    
    Context "When assign duplicate is true and current website has same bindings" {
    
        Mock Run-command {return "SITE SampleWeb (id:1,bindings:$binding1,state:Started)"} -ParameterFilter { $failOnErr -eq $false }

        $result = Does-BindingExists -siteName "SampleWeb" -protocol $protocol -ipAddress $ipAddress -port $port -hostname $hostname -assignDupBindings "true"

        It "Does-BindingExists should return true"{
            $result | Should Be $true
        }
    }

    Context "When assign duplicate is true and another website has same bindings" {

        Mock Run-command {return "SITE AnotherSite (id:1,bindings:$binding1,state:Started)"} -ParameterFilter { $failOnErr -eq $false }

        $result = Does-BindingExists -siteName "SampleWeb" -protocol $protocol -ipAddress $ipAddress -port $port -hostname $hostname -assignDupBindings "true"
        
        It "Does-BindingExists should return false"{
            $result | Should Be $false
        }
    }

    Context "When assign duplicate is false, current and another website has same bindings" {

        Mock Run-command {return @("SITE SampleWeb (id:1,bindings:$binding1,state:Started)" , 
                        "SITE AnotherSite (id:1,bindings:$binding1,state:Started)")} -ParameterFilter { $failOnErr -eq $false }

        try
        {
            $result = Does-BindingExists -siteName "SampleWeb" -protocol $protocol -ipAddress $ipAddress -port $port -hostname $hostname -assignDupBindings "false"
        }
        catch
        {
            $result = $_.Exception.Message
        }
        
        
        It "Does-BindingExists should throw exception"{
            ($result.Contains('Binding already exists for website')) | Should Be $true
        }
    }

    Context "When assign duplicate is false, current has same binding and no other website has same bindings" {
        
        Mock Run-command {return @("SITE SampleWeb (id:1,bindings:$binding1,state:Started)" , 
                        "SITE AnotherSite (id:1,bindings:$binding2,state:Started)")} -ParameterFilter { $failOnErr -eq $false }

        $result = Does-BindingExists -siteName "SampleWeb" -protocol $protocol -ipAddress $ipAddress -port $port -hostname $hostname -assignDupBindings "false"
        
        It "Does-BindingExists should return true"{
            $result | Should Be $true
        }
    }

    Context "When assign duplicate is false, any other website has same bindings" {

        Mock Run-command {return @("SITE SampleWeb (id:1,bindings:$binding2,state:Started)" , 
                        "SITE AnotherSite (id:1,bindings:$binding1,state:Started)")} -ParameterFilter { $failOnErr -eq $false }

        try
        {
            $result = Does-BindingExists -siteName "SampleWeb" -protocol $protocol -ipAddress $ipAddress -port $port -hostname $hostname -assignDupBindings "false"
        }
        catch
        {
            $result = $_.Exception.Message
        }
        
        
        It "Does-BindingExists should throw exception"{
            ($result.Contains('Binding already exists for website')) | Should Be $true
        }
    }
}

Describe "Tests for verifying Does-AppPoolExists functionality" {

    Mock Get-AppCmdLocation {return "appcmd.exe", 8}

    Context "List Application Pools command returns null." {

        Mock Run-command { return $null } -ParameterFilter { $failOnErr -eq $false }

        $result = Does-AppPoolExists -appPoolName "SampleAppPool"
        
        It "function should return false" {
           $result | Should Be $false
        }
    }

    Context "List Application Pools command returns non-null" {

        Mock Run-command { return "" } -ParameterFilter { $failOnErr -eq $false }
        
        $result = Does-AppPoolExists -appPoolName "SampleAppPool"

        It "function should return true" {
            $result | Should Be $true
        }
    }
}

Describe "Tests for verifying Enable-SNI functionality" {

    $ipAddress = "All Unassigned"
    Context "Enable SNI should return if iisVerision is less than 8" {

        Mock Run-Command { return }
        Mock Get-AppCmdLocation -Verifiable {return "", 7}

        Enable-SNI -siteName "SampleWeb" -sni "true" -ipAddress $ipAddress -port "80" -hostname "localhost"

        It "Should not enable SNI"{
            Assert-VerifiableMocks
            Assert-MockCalled Run-Command -Times 0
        }
    }

    Context "Enable SNI should return if SNI is false" {

        Mock Run-Command { return }
        Mock Get-AppCmdLocation -Verifiable {return "", 8}

        Enable-SNI -siteName "SampleWeb" -sni "false" -ipAddress $ipAddress -port "80" -hostname "localhost"

        It "Should not enable SNI"{
            Assert-VerifiableMocks
            Assert-MockCalled Run-Command -Times 0
        }
    }

    Context "Enable SNI should return if hostname is empty" {

        Mock Run-Command { return }
        Mock Get-AppCmdLocation -Verifiable {return "", 8}

        Enable-SNI -siteName "SampleWeb" -sni "true" -ipAddress $ipAddress -port "80" -hostname ""

        It "Should not enable SNI"{
            Assert-VerifiableMocks
            Assert-MockCalled Run-Command -Times 0
        }
    }

    Context "Enable SNI should succeed for valid inputs" {

        Mock Run-Command -Verifiable { return }
        Mock Get-AppCmdLocation -Verifiable {return "", 8}

        $output = Enable-SNI -siteName "SampleWeb" -sni "true" -ipAddress $ipAddress -port "80" -hostname "localhost" 4>&1 | Out-String

        It "Should enable SNI"{
            ( $output.Contains('].sslFlags:"1"') ) | Should Be $true
            Assert-VerifiableMocks
        }
    }
}

Describe "Tests for verifying Add-SslCert functionality" {

    Context "When certhash is empty" {

        Mock Run-Command { return } -ParameterFilter { $failOnErr -eq $false }

        Add-SslCert -certhash ""

        It "Should not add SslCert"{
            Assert-MockCalled Run-command -Exactly -Times 0
        }
    }

    Context "Given hostnameport for cert exists" {

        Mock Run-Command { return } -ParameterFilter { }
        Mock Run-Command -Verifiable {return "", "" , "" , "", "HostName:port                : localhost:80", "Certificate Hash             : SampleHash"} -ParameterFilter { $failOnErr -eq $false }

        $output = Add-SslCert -port "80" -certhash "SampleHash" -hostname "localhost" -sni "true" -iisVersion "8.0" 4>&1 | Out-String

        It "Should not add hostnameport for cert"{
            ($output.Contains('netsh http show sslcert hostnameport=localhost:80')) | Should Be $true

            Assert-MockCalled Run-command -Times 1 -Exactly -ParameterFilter { $failOnErr -eq $false }
            Assert-MockCalled Run-Command -Times 0 -Exactly -ParameterFilter { }
        }
    }

    Context "Given ipport for cert exists" {

        Mock Run-Command { return } -ParameterFilter { }
        Mock Run-Command {return "", "" , "" , "", "IP:port                      : 0.0.0.0:80", "Certificate Hash             : samplehash"}  -ParameterFilter { $failOnErr -eq $false }

        $output = Add-SslCert -port "80" -certhash "SampleHash" -hostname "localhost" -sni "true" -iisVersion "7.0" 4>&1 | Out-String

        It "Should not add cert"{
            ($output.Contains('netsh http show sslcert ipport=0.0.0.0:80')) | Should Be $true
            ($output.Contains('SSL cert binding already present.. returning')) | Should Be $true
            Assert-MockCalled Run-command -Times 1 -Exactly -ParameterFilter { $failOnErr -eq $false }
            Assert-MockCalled Run-command -Times 0 -Exactly -ParameterFilter { }
        }
    }

    Context "Given hostnameport for cert does not exists" {

        Mock Run-Command { return }
        Mock Run-Command {return "", "" , "" , "", "", ""} -ParameterFilter { $failOnErr -eq $false }

        $output = Add-SslCert -port "80" -certhash "SampleHash" -hostname "localhost" -sni "true" -iisVersion "8.0" 4>&1 | Out-String

        It "Should add hostnameport entry for given cert"{
            ($output.Contains('netsh http show sslcert hostnameport=localhost:80')) | Should Be $true
            Assert-MockCalled Run-command -Times 1 -Exactly -ParameterFilter { $failOnErr -eq $false }
            Assert-MockCalled Run-command -Times 1
        }
    }
}

Describe "Tests for verifying Deploy-WebSite functionality" {

    Context "It should append msDeploy path and msDeploy args and run"{

        $msDeploy = "Msdeploy.exe"
        $msDeployArgs = " -verb:sync -source:package=Web.zip -setParamFile=SampleParam.xml"
        
        Mock Run-Command -Verifiable { return }
        Mock Get-MsDeployLocation -Verifiable { return $msDeploy }
        Mock Get-MsDeployCmdArgs -Verifiable { return $msDeployArgs }

        $output = Deploy-WebSite -webDeployPkg "Web.zip" -webDeployParamFile "SampleParam.xml" 4>&1 | Out-String

        It "Should contain both msDeploy and msDeployArgs"{
            ($output.Contains("$msDeploy")) | Should Be $true
            ($output.Contains("$msDeployArgs")) | Should Be $true
            Assert-VerifiableMocks
        }
    }
}

Describe "Tests for verifying Create-WebSite functionality" {

    Context "It should run appcmd add site command"{

        $appCmd = "appcmd.exe"
        $appCmdArgs = " add site /name:`"Sample Web`" /physicalPath:`"C:\Temp Path`""
        
        Mock Run-Command -Verifiable { return }
        Mock Get-AppCmdLocation -Verifiable { return $appCmd, 8 }

        $output = Create-WebSite -siteName "Sample Web" -physicalPath "C:\Temp Path" 4>&1 | Out-String

        It "Should contain appcmd add site"{
            ($output.Contains("$appCmd")) | Should Be $true
            ($output.Contains("$appCmdArgs")) | Should Be $true
            Assert-VerifiableMocks
        }
    }
}

Describe "Tests for verifying Create-AppPool functionality" {

    Context "It should run appcmd add apppool command"{

        $appCmd = "appcmd.exe"
        $appCmdArgs = " add apppool /name:`"Sample App Pool`""
        
        Mock Run-Command -Verifiable { return }
        Mock Get-AppCmdLocation -Verifiable { return $appCmd, 8 }

        $output = Create-AppPool -appPoolName "Sample App Pool" 4>&1 | Out-String

        It "Should contain appcmd add site"{
            ($output.Contains("$appCmd")) | Should Be $true
            ($output.Contains("$appCmdArgs")) | Should Be $true
            Assert-VerifiableMocks
        }
    }
}

Describe "Tests for verifying Run-AdditionalCommands functionality" {

    $AppCmdRegKey = "HKLM:\SOFTWARE\Microsoft\InetStp"

    Context "When additional commands is empty"{
            
        Mock Get-AppCmdLocation { return "appcmd.exe", 8 } -ParameterFilter { $RegKeyPath -eq $AppCmdRegKey }
        Mock Run-Command  { return }

        $output = Run-AdditionalCommands -additionalCommands "" 4>&1 | Out-String

        It "Should return"{
            ([string]::IsNullOrEmpty($output)) | Should Be $true
            Assert-MockCalled Get-AppCmdLocation -Exactly -Times 1
            Assert-MockCalled Run-Command -Exactly -Times 0
        }
    }

     Context "When one additional command is given"{

        $command1 = "set apppool"
        Mock Get-AppCmdLocation -Verifiable { return "appcmd.exe", 8 } -ParameterFilter { $RegKeyPath -eq $AppCmdRegKey }
        Mock Run-Command  { return }

        $output = Run-AdditionalCommands -additionalCommands $command1 4>&1 | Out-String

        It "Should return"{
            ($output.Contains("$command1")) | Should Be $true
            Assert-MockCalled Get-AppCmdLocation -Exactly -Times 1
            Assert-MockCalled Run-Command -Exactly -Times 1
        }
    }

    Context "When two additional commands is given"{

        $command1 = "set apppool"
        $command2 = "set website"

        $commands = $command1 + [System.Environment]::NewLine + $command2
        Mock Get-AppCmdLocation -Verifiable { return "appcmd.exe", 8 } -ParameterFilter { $RegKeyPath -eq $AppCmdRegKey }
        Mock Run-Command  { return }

        $output = Run-AdditionalCommands -additionalCommands $commands 4>&1 | Out-String

        It "Should return"{
            ($output.Contains("$command1")) | Should Be $true
            ($output.Contains("$command2")) | Should Be $true
            Assert-MockCalled Get-AppCmdLocation -Exactly -Times 1
            Assert-MockCalled Run-Command -Exactly -Times 2
        }
    }

    Context "When two additional commands with an empty line in between is given"{

        $command1 = "set apppool"
        $command2 = " "
        $command3 = "set website"

        $commands = $command1 + [System.Environment]::NewLine + $command2 + [System.Environment]::NewLine + $command3
        Mock Get-AppCmdLocation -Verifiable { return "appcmd.exe", 8 } -ParameterFilter { $RegKeyPath -eq $AppCmdRegKey }
        Mock Run-Command  { return }

        $output = Run-AdditionalCommands -additionalCommands $commands 4>&1 | Out-String

        It "Should return"{
            ($output.Contains("$command1")) | Should Be $true
            ($output.Contains("$command2")) | Should Be $true
            Assert-MockCalled Get-AppCmdLocation -Exactly -Times 1
            Assert-MockCalled Run-Command -Exactly -Times 2
        }
    }

    Context "When two additional commands with an new line in between is given"{

        $command1 = "set apppool"        
        $command2 = "set website"

        $commands = $command1 + [System.Environment]::NewLine + [System.Environment]::NewLine + [System.Environment]::NewLine + $command2
        Mock Get-AppCmdLocation -Verifiable { return "appcmd.exe", 8 } -ParameterFilter { $RegKeyPath -eq $AppCmdRegKey }
        Mock Run-Command  { return }

        $output = Run-AdditionalCommands -additionalCommands $commands 4>&1 | Out-String

        It "Should return"{
            ($output.Contains("$command1")) | Should Be $true
            ($output.Contains("$command2")) | Should Be $true
            Assert-MockCalled Get-AppCmdLocation -Exactly -Times 1
            Assert-MockCalled Run-Command -Exactly -Times 2
        }
    }

    Context "When multiple commands are given and second command fails and hence Run-Command throws exception"{

        $command1 = "set apppool"        
        $command2 = "set website"
        $command3 = "list sites"
        $command4 = "list apppools"
        $errorMsg = "Failed to run command"

        $commands = $command1 + [System.Environment]::NewLine + $command2 + [System.Environment]::NewLine + $command3 + [System.Environment]::NewLine + $command4
        Mock Get-AppCmdLocation -Verifiable { return "appcmd.exe", 8 } -ParameterFilter { $RegKeyPath -eq $AppCmdRegKey }
        Mock Run-Command { return } -ParameterFilter { $command -ne "`"appcmd.exe`" $command2" }
        Mock Run-Command  { throw $errorMsg } -ParameterFilter { $command -eq "`"appcmd.exe`" $command2"}
        


        It "Should return"{
            { Run-AdditionalCommands -additionalCommands $commands } | Should Throw $errorMsg 
            Assert-MockCalled Get-AppCmdLocation -Exactly -Times 1
            Assert-MockCalled Run-Command -Exactly -Times 1 -ParameterFilter { $command -eq "`"appcmd.exe`" $command2" }
            Assert-MockCalled Run-Command -Exactly -Times 1 -ParameterFilter { $command -ne "`"appcmd.exe`" $command2" }

        }
    }

    Context "When multiple commands are given and last command fails and hence Run-Command throws exception"{

        $command1 = "set apppool"        
        $command2 = "set website"
        $command3 = "list sites"
        $command4 = "list apppools"
        $errorMsg = "Failed to run command"

        $commands = $command1 + [System.Environment]::NewLine + $command2 + [System.Environment]::NewLine + $command3 + [System.Environment]::NewLine + $command4
        Mock Get-AppCmdLocation -Verifiable { return "appcmd.exe", 8 } -ParameterFilter { $RegKeyPath -eq $AppCmdRegKey }
        Mock Run-Command { return } -ParameterFilter { $command -ne "`"appcmd.exe`" $command4" }
        Mock Run-Command  { throw $errorMsg } -ParameterFilter { $command -eq "`"appcmd.exe`" $command4"}
        


        It "Should return"{
            { Run-AdditionalCommands -additionalCommands $commands } | Should Throw $errorMsg
            Assert-MockCalled Get-AppCmdLocation -Exactly -Times 1
            Assert-MockCalled Run-Command -Exactly -Times 1 -ParameterFilter { $command -eq "`"appcmd.exe`" $command4" }
            Assert-MockCalled Run-Command -Exactly -Times 3 -ParameterFilter { $command -ne "`"appcmd.exe`" $command4" }

        }
    }
}

Describe "Tests for verifying Update-WebSite functionality" {

    Context "when all the inputs are given"{

        $appCmd = "appcmd.exe"
        
        Mock Run-Command -Verifiable { return }
        Mock Get-AppCmdLocation -Verifiable { return $appCmd, 8 }
        Mock Does-BindingExists -Verifiable { return $false } -ParameterFilter { $SiteName -eq "Sample Web" }

        $output = Update-WebSite -siteName "Sample Web" -appPoolName "App Pool" -physicalPath "C:\Temp Path" -authType "WebSiteWindowsAuth" -userName "localuser" -password "SomePassword" -addBinding "true" -protocol "http" -ipAddress "All Unassigned" -port "80" -hostname "localhost"  4>&1 | Out-String

        It "Should contain appropriate options in command line"{
            ($output.Contains("-applicationDefaults.applicationPool")) | Should Be $true
            ($output.Contains("-[path='/'].[path='/'].physicalPath:")) | Should Be $true
            ($output.Contains("-[path='/'].[path='/'].userName:")) | Should Be $true
            ($output.Contains("-[path='/'].[path='/'].password:")) | Should Be $true
            ($output.Contains("/+bindings.[protocol='http',bindingInformation='*:80:localhost']")) | Should Be $true            
            Assert-VerifiableMocks
        }
    }

    Context "When authType is passthrough, AppPool is not given and binding already existing"{

        $appCmd = "appcmd.exe"

        Mock Run-Command -Verifiable { return }
        Mock Get-AppCmdLocation -Verifiable { return $appCmd, 8 }
        Mock Does-BindingExists -Verifiable { return $true } -ParameterFilter { $SiteName -eq "SampleWeb" }
         
        $output = Update-WebSite -siteName "SampleWeb" -physicalPath "C:\Temp" -authType "PassThrough" -addBinding "true" -protocol "http" -ipAddress "`"All Unassigned`"" -port "80" -hostname "localhost" 4>&1 | Out-String

        It "Should contain appropriate options in command line"{
            ($output.Contains("-applicationDefaults.applicationPool")) | Should Be $false
            ($output.Contains("-[path='/'].[path='/'].physicalPath:")) | Should Be $true
            ($output.Contains("-[path='/'].[path='/'].userName:")) | Should Be $false
            ($output.Contains("-[path='/'].[path='/'].password:")) | Should Be $false
            ($output.Contains("/+bindings")) | Should Be $false
            Assert-VerifiableMocks
        }
    }

    Context "When authType is passthrough, AppPool is not given and add binding is false"{

        $appCmd = "appcmd.exe"

        Mock Run-Command -Verifiable { return }
        Mock Get-AppCmdLocation -Verifiable { return $appCmd, 8 }
        Mock Does-BindingExists -Verifiable { return $false } -ParameterFilter { $SiteName -eq "SampleWeb" }
         
        $output = Update-WebSite -siteName "SampleWeb" -physicalPath "C:\Temp" -authType "PassThrough" -addBinding "false" -protocol "http" -ipAddress "`"All Unassigned`"" -port "80" -hostname "localhost" 4>&1 | Out-String

        It "Should contain appropriate options in command line"{
            ($output.Contains("-applicationDefaults.applicationPool")) | Should Be $false
            ($output.Contains("-[path='/'].[path='/'].physicalPath:")) | Should Be $true
            ($output.Contains("-[path='/'].[path='/'].userName:")) | Should Be $false
            ($output.Contains("-[path='/'].[path='/'].password:")) | Should Be $false
            ($output.Contains("/+bindings")) | Should Be $false
            Assert-VerifiableMocks
        }
    }
}

Describe "Tests for verifying Update-AppPool functionality" {

    Context "when all the inputs are given non default values"{

        $appCmd = "appcmd.exe"
        $AppCmdRegKey = "HKLM:\SOFTWARE\Microsoft\InetStp"
        
        Mock Run-Command -Verifiable { return }
        Mock Get-AppCmdLocation -Verifiable { return $appCmd, 8 } -ParameterFilter { $RegKeyPath -eq $AppCmdRegKey }

        $output = Update-AppPool -appPoolName "SampleAppPool" -clrVersion "v2.0" -pipeLineMode "Classic" -identity "SpecificUser" -userName "TestUser" -password "SamplePassword" 4>&1 | Out-String
        Write-Verbose $output -Verbose

        It "Should contain appropriate options in command line"{
            ($output.Contains(" set config")) | Should Be $true
            ($output.Contains("-section:system.applicationHost/applicationPools")) | Should Be $true
            ($output.Contains('/[name=''"SampleAppPool"''].managedRuntimeVersion:v2.0')) | Should Be $true
            ($output.Contains('/[name=''"SampleAppPool"''].managedPipelineMode:Classic')) | Should Be $true
            ($output.Contains('/[name=''"SampleAppPool"''].processModel.identityType:SpecificUser')) | Should Be $true
            ($output.Contains('/[name=''"SampleAppPool"''].processModel.userName:"TestUser"')) | Should Be $true
            ($output.Contains('/[name=''"SampleAppPool"''].processModel.password:"SamplePassword"')) | Should Be $true
            Assert-VerifiableMocks
        }
    }

    Context "when all the inputs are given default values exception identity"{

        $appCmd = "appcmd.exe"
        $AppCmdRegKey = "HKLM:\SOFTWARE\Microsoft\InetStp"
        
        Mock Run-Command -Verifiable { return }
        Mock Get-AppCmdLocation -Verifiable { return $appCmd, 8 } -ParameterFilter { $RegKeyPath -eq $AppCmdRegKey }

        $output = Update-AppPool -appPoolName "SampleAppPool" -clrVersion "v4.0" -pipeLineMode "Integrated" -identity "LocalService" 4>&1 | Out-String
        Write-Verbose $output -Verbose

        It "Should contain appropriate options in command line"{
            ($output.Contains(" set config")) | Should Be $true
            ($output.Contains("-section:system.applicationHost/applicationPools")) | Should Be $true
            ($output.Contains('/[name=''"SampleAppPool"''].managedRuntimeVersion:v4.0')) | Should Be $true
            ($output.Contains('/[name=''"SampleAppPool"''].managedPipelineMode:Integrated')) | Should Be $true
            ($output.Contains('/[name=''"SampleAppPool"''].processModel.identityType:LocalService')) | Should Be $true
            ($output.Contains('/[name=''"SampleAppPool"''].processModel.userName:')) | Should Be $false           
            ($output.Contains('/[name=''"SampleAppPool"''].processModel.password:')) | Should Be $false
            Assert-VerifiableMocks
        }
    }
    
}

Describe "Tests for verifying Create-And-Update-WebSite functionality" {

    Context "When website does not exist" {

        Mock Does-WebSiteExists -Verifiable { return $false } -ParameterFilter { $SiteName -eq "SampleWeb" }
        Mock Create-WebSite -Verifiable { return } -ParameterFilter { $siteName -eq "SampleWeb" }
        Mock Update-WebSite -Verifiable { return } -ParameterFilter { $siteName -eq "SampleWeb" }

        Create-And-Update-WebSite -siteName "SampleWeb"

        It "Create website should be called"{
            Assert-VerifiableMocks
        }
    }

    Context "When website exist" {

        Mock Does-WebSiteExists -Verifiable { return $true } -ParameterFilter { $SiteName -eq "SampleWeb" }
        Mock Create-WebSite { return } -ParameterFilter { $siteName -eq "SampleWeb" }
        Mock Update-WebSite -Verifiable { return } -ParameterFilter { $siteName -eq "SampleWeb" }

        Create-And-Update-WebSite -siteName "SampleWeb"

        It "Create website should not be called"{
            Assert-VerifiableMocks
            Assert-MockCalled Create-WebSite -Times 0 -Exactly
        }
    }
}

Describe "Tests for verifying Create-And-Update-AppPool functionality" {

    Context "When application pool does not exist" {

        Mock Does-AppPoolExists -Verifiable { return $false } -ParameterFilter { $AppPoolName -eq "SampleAppPool" }
        Mock Create-AppPool -Verifiable { return } -ParameterFilter { $AppPoolName -eq "SampleAppPool" }
        Mock Update-AppPool -Verifiable { return } -ParameterFilter { $AppPoolName -eq "SampleAppPool" -and $ClrVersion -eq "2.0" -and $PipeLineMode -eq "Integrated" -and $Identity -eq "SpecificUser" -and $UserName -eq "dummyUser" -and $Password -eq "DummyPassword"}
        
        Create-And-Update-AppPool -appPoolName "SampleAppPool" -clrVersion "2.0" -pipeLineMode "Integrated" -identity "SpecificUser" -userName "dummyUser" -password "DummyPassword"

        It "Create application pool should be called"{
            Assert-VerifiableMocks
        }
    }

    Context "When application pool exist" {

        Mock Does-AppPoolExists -Verifiable { return $true } -ParameterFilter { $AppPoolName -eq "SampleAppPool" }
        Mock Create-AppPool { return } -ParameterFilter { $AppPoolName -eq "SampleAppPool" }
        Mock Update-AppPool -Verifiable { return } -ParameterFilter { $AppPoolName -eq "SampleAppPool"  -and $ClrVersion -eq "2.0" -and $PipeLineMode -eq "Integrated" -and $Identity -eq "SpecificUser" -and $UserName -eq "dummyUser" -and $Password -eq "DummyPassword"}

        Create-And-Update-AppPool -appPoolName "SampleAppPool" -clrVersion "2.0" -pipeLineMode "Integrated" -identity "SpecificUser" -userName "dummyUser" -password "DummyPassword"

        It "Create application pool should not be called"{
            Assert-VerifiableMocks
            Assert-MockCalled Create-AppPool -Times 0 -Exactly
        }
    }
}

Describe "Tests for verifying Execute-Main functionality" {

    $AppCmdCommands = "ExtraCommands"
    $WebDeployPackage = "WebDeploy.Pkg"
    $WebsiteName = "SampleWeb"
    Mock Run-AdditionalCommands -Verifiable { return } -ParameterFilter { $additionalCommands -eq $AppCmdCommands }

    Context "createAppPool is false"{

        $AppPoolName = "SampleAppPool"
        $CreateAppPool = "false"
        $CreateWebsite = "true"

        Mock Deploy-WebSite -Verifiable { return } -ParameterFilter { $webDeployPkg -eq $WebDeployPackage }
        Mock Create-And-Update-WebSite -Verifiable { return } -ParameterFilter { $WebsiteName -eq $WebsiteName }
        Mock Create-And-Update-AppPool { return } -ParameterFilter { $appPoolName -eq $AppPoolName }

        Execute-Main -AppPoolName $AppPoolName -CreateWebsite $CreateWebsite -CreateAppPool $CreateAppPool

        It "Create and update application pool should not be called"{
            Assert-VerifiableMocks
            Assert-MockCalled Create-And-Update-AppPool -Times 0
        }
    }

    Context "createAppPool is true"{

        $AppPoolName = "SampleAppPool"
        $createAppPool = "true"
        $CreateWebsite = "true"

        Mock Deploy-WebSite -Verifiable { return } -ParameterFilter { $webDeployPkg -eq $WebDeployPackage }
        Mock Create-And-Update-WebSite -Verifiable { return } -ParameterFilter { $WebsiteName -eq $WebsiteName }
        Mock Create-And-Update-AppPool -Verifiable { return } -ParameterFilter { $appPoolName -eq $AppPoolName }        

        Execute-Main -AppPoolName $AppPoolName -CreateWebsite $CreateWebsite -CreateAppPool $CreateAppPool

        It "Create and update application pool should be called"{
            Assert-VerifiableMocks
        }
    }
    
    Context "CreateWebSite is false and website exits"{

        $CreateWebsite = "false"

        Mock Deploy-WebSite -Verifiable { return } -ParameterFilter { $webDeployPkg -eq $WebDeployPackage }
        Mock Create-And-Update-WebSite { return } -ParameterFilter { $SiteName -eq $WebsiteName }
        Mock Does-WebSiteExists -Verifiable { return $true } -ParameterFilter { $SiteName -eq $WebsiteName }

        Execute-Main -CreateWebsite $CreateWebsite

        It "No exception should be thrown"{
            Assert-VerifiableMocks
            Assert-MockCalled Create-And-Update-WebSite -Times 0
        }
    }

    Context "CreateWebSite is false and website does not exist"{

        $CreateWebsite = "false"
        $errorMsg = "Website does not exist and you did not request to create it - deployment cannot continue."
                
        Mock Create-And-Update-WebSite { return } -ParameterFilter { $SiteName -eq $WebsiteName }
        Mock Does-WebSiteExists -Verifiable { return $false } -ParameterFilter { $SiteName -eq $WebsiteName }

        It "Exception should be thrown"{
            { Execute-Main -CreateWebsite $CreateWebsite -WebsiteName $WebsiteName } | Should Throw $errorMsg
            Assert-VerifiableMocks
            Assert-MockCalled Create-And-Update-WebSite -Times 0
        }

    }

    Context "CreateWebSite is true"{

        $Protocol = "http"
        $CreateWebsite = "true"

        Mock Deploy-WebSite -Verifiable { return } -ParameterFilter { $webDeployPkg -eq $WebDeployPackage }
        Mock Create-And-Update-WebSite -Verifiable { return } -ParameterFilter { $SiteName -eq $WebsiteName }
        Mock Add-SslCert { return }
        Mock Enable-SNI { return }

        Execute-Main -CreateWebsite $CreateWebsite -Protocol $Protocol

        It "Create and update website should be called"{
            Assert-VerifiableMocks
            Assert-MockCalled Add-SslCert -Times 0
            Assert-MockCalled Enable-SNI -Times 0
        }
    }

    Context "CreateWebSite is true and protocol is https"{

        $Protocol = "https"
        $SslCertThumbPrint = "SampleHash"
        $CreateWebsite = "true"

        Mock Deploy-WebSite -Verifiable { return } -ParameterFilter { $webDeployPkg -eq $WebDeployPackage }
        Mock Create-And-Update-WebSite -Verifiable { return } -ParameterFilter { $SiteName -eq $WebsiteName }
        Mock Add-SslCert -Verifiable { return } -ParameterFilter { $Certhash -eq $SslCertThumbPrint }
        Mock Enable-SNI -Verifiable { return } -ParameterFilter { $SiteName -eq $WebsiteName }
        Mock Get-AppCmdLocation -Verifiable { return "appcmd.exe", 8 }

        Execute-Main -CreateWebsite $CreateWebsite -Protocol $Protocol -SslCertThumbPrint $SslCertThumbPrint

        It "Create and update website should be called along with setting cert and SNI"{
            Assert-VerifiableMocks
        }
    }
}
