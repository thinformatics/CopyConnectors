<#
    .SYNOPSIS
    Powershell Log File Search -CopyConnector.ps1
   
   	Kristian Schmidt, Christian Reetz
    (Updated by Christian Reetz)
	
	THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE 
	RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
	
	30.03.2022
	
    .DESCRIPTION
    Tool to Copy ReceiveConnectors
    

    #>

#Muss direkt in der Exchange PS gestartet werden. Mit dem Session Aufruf führt es zu Fehlern.
#$Session = New-PSSession -ConfigurationName "Microsoft.Exchange" -ConnectionUri http://bb-ex2016-ex2/PowerShell/ -Authentication Kerberos
#Import-PSSession -Session $Session -AllowClobber 

#DebugMode
#Im Debug Mode werden die Connectoren nicht angelegt.
#[bool]$DebugMode=$True

$DomainController = (Get-ADDomainController).HostName

#Abfrage des Source Exchange Servers
$SourceExchangeServer = read-host "Specify source Exchange Server" 
#$SourceExchangeServer = "bb-ex2016-ex01"
$SourceExchangeServer = (get-exchangeserver $SourceExchangeServer | select name).name

#Abfrage des Targetservers
$NewExchangeServer = read-host "Specify targed Exchange Server" 
#$NewExchangeServer = "bb-ex2016-ex2"
$NewExchangeServer = (get-exchangeserver $NewExchangeServer | select name).name

#Fragt alle Receiveconnectors des Sourceservers ab
[array]$ReceiveConnectors = Get-ReceiveConnector -Server $SourceExchangeServer -DomainController $DomainController | Where-Object -FilterScript {$_.Name -notlike "*Default*" -and $_.Name -notlike "*Client*" -and $_.Name -notlike "*Proxy*"}

function menu($DomainController,$SourceExchangeServer,$NewExchangeServer,$ReceiveConnectors)  {

    #Gibt die Connectors aus und man wählt einen zum kopieren aus
    $output = @()
    $i = 0
    $ReceiveConnectors = $ReceiveConnectors | Sort-Object transportrole,identity
    $ReceiveConnectors | select identity, bindings, enabled, transportrole | foreach {
        $i++
        $output += "#$i | $($_.Transportrole), Enabeld=$($_.Enabled), $($_.identity)"
    }
    
    echo "---------------------------------------------------------"  
    echo ""
    echo "               Copy Receive Connector"
    echo ""
    $output
    echo "#0 | To Quit"
    echo "---------------------------------------------------------"  
    echo "" 
    
    #Eingabe welcher Connector kopiert werden soll
    $choice = Read-Host "Which Connector do you want to copy? (Example: 1 or 0 to quit)"
    
    #Bei 0 wird das Script abgebrochen
    if($choice -eq "0"){exit}

    $SelectedConnector = $ReceiveConnectors[($choice-1)]

    #Es werden die Wert des Connectors ausgelesen und in die Variable Parameters geschrieben. 
    #Wenn in dem Wert PermissionGroups ausschließlich Custom steht, dann kann es beim Anlegen zu Fehlern kommen und man muss Exchange Server etc. eintragen
    #und die danach wieder entfernen.

    $SelectedConnector | foreach {
        #if ($_.usage -eq $null) {$usage = "custom"} else {$usage = $_.usage }
        $Parameters = @{
	        Usage = "custom"
            TransportRole = $_.TransportRole
            Name = $_.Name 
            AuthMechanism = $_.AuthMechanism 
            BinaryMimeEnabled = $_.BinaryMimeEnabled 
            Bindings = $_.Bindings 
            ChunkingEnabled = $_.ChunkingEnabled 
            DeliveryStatusNotificationEnabled = $_.DeliveryStatusNotificationEnabled 
            EightBitMimeEnabled = $_.EightBitMimeEnabled 
            DomainSecureEnabled = $_.DomainSecureEnabled 
            EnhancedStatusCodesEnabled = $_.EnhancedStatusCodesEnabled 
            LongAddressesEnabled = $_.LongAddressesEnabled 
            OrarEnabled = $_.OrarEnabled 
            SuppressXAnonymousTls = $_.SuppressXAnonymousTls 
            AdvertiseClientSettings = $_.AdvertiseClientSettings 
            ServiceDiscoveryFqdn = $_.ServiceDiscoveryFqdn 
            TlsCertificateName = $_.TlsCertificateName 
            Comment = $_.Comment 
            Enabled = $_.Enabled 
            ConnectionTimeout = $_.ConnectionTimeout 
            ConnectionInactivityTimeout = $_.ConnectionInactivityTimeout 
            MessageRateLimit = $_.MessageRateLimit 
            MessageRateSource = $_.MessageRateSource 
            MaxInboundConnection = $_.MaxInboundConnection 
            MaxInboundConnectionPerSource = $_.MaxInboundConnectionPerSource 
            MaxInboundConnectionPercentagePerSource = $_.MaxInboundConnectionPercentagePerSource 
            MaxHeaderSize = $_.MaxHeaderSize 
            MaxHopCount = $_.MaxHopCount 
            MaxLocalHopCount = $_.MaxLocalHopCount 
            MaxLogonFailures = $_.MaxLogonFailures 
            MaxMessageSize = $_.MaxMessageSize
            MaxProtocolErrors = $_.MaxProtocolErrors 
            MaxRecipientsPerMessage = $_.MaxRecipientsPerMessage 
            PermissionGroups = $_.PermissionGroups
            PipeliningEnabled = $_.PipeliningEnabled 
            ProtocolLoggingLevel = $_.ProtocolLoggingLevel 
            RemoteIPRanges = $_.RemoteIPRanges 
            RequireEHLODomain = $_.RequireEHLODomain 
            RequireTLS = $_.RequireTLS 
            EnableAuthGSSAPI = $_.EnableAuthGSSAPI 
            ExtendedProtectionPolicy = $_.ExtendedProtectionPolicy 
            TlsDomainCapabilities = $_.TlsDomainCapabilities 
            SizeEnabled = $_.SizeEnabled 
            TarpitInterval = $_.TarpitInterval 
            MaxAcknowledgementDelay = $_.MaxAcknowledgementDelay 
            Server = $NewExchangeServer 
        }
        
        if($DebugMode -eq $True){
        Write-Host "DEBUGMODE"
        Write-Host "New connector ""$($Parameters.name)"""
        }
        else{
        #Erstellen des neuen Connectors
        New-ReceiveConnector @parameters -DomainController $DomainController
        }
    }

    #Permissions aus dem zu kopierenden Connector auslesen
    $ReceiveConnectorPermissions=Get-ReceiveConnector -Identity $SelectedConnector.Identity | Get-ADPermission | ?{$_.ExtendedRights -ne $null} | select identity,user,extendedrights
    
    #Den neunen Targetconnector in die Variable übernehmen
    $TargetConnector = Get-ReceiveConnector -Identity "$NewExchangeServer\$($SelectedConnector.name)"

    #Prüfen ob der Targetconnector korrekt angelegt wurde und gefunden wurde, oder ob es Probleme gab und in der Targetconnecor Variable alle enthalten sind. 
    if($TargetConnector.count -ne "1"){
    
    Read-Host "Targetconnector could not be found. The script stop after pressing Enter"
    exit
    
    }
    
    if($DebugMode -eq $True){
        Write-Host "DEBUGMODE"
        Write-Host "Connector on wich the permissions are set ""$($TargetConnector)"""
    }

    else{
        foreach($entry in $ReceiveConnectorPermissions){
        
        #Setzen der Berechtigungen für den Connector    
        Get-ReceiveConnector $TargetConnector | add-ADPermission -User $entry.user -ExtendedRights $entry.ExtendedRights
    
        }
    }
    #Funktion wird erneut aufgerufen, sodass man einen weiteren Connector kopieren kann
    menu -DomainController $DomainController -SourceExchangeServer $SourceExchangeServer -NewExchangeServer $NewExchangeServer -ReceiveConnectors $ReceiveConnectors
}
menu -DomainController $DomainController -SourceExchangeServer $SourceExchangeServer -NewExchangeServer $NewExchangeServer -ReceiveConnectors $ReceiveConnectors  