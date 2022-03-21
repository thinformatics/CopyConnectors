<#
    .SYNOPSIS
    Powershell Log File Search -CopyConnector.ps1

    Kristian Schmidt, Christian Reetz
    (Updated by Christian Reetz)

    THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE
    RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.

    18.03.2022

    .DESCRIPTION
    Tool to Copy ReceiveConnectors
#>

$DomainController = (Get-ADDomainController).HostName
    
$SourceExchangeServer = read-host "Specify source Exchange Server"
$SourceExchangeServer = (get-exchangeserver $SourceExchangeServer | select-object name).name
 
$NewExchangeServer = read-host "Specify targed Exchange Server"
$NewExchangeServer = (get-exchangeserver $NewExchangeServer | select-object name).name

[array]$ReceiveConnectors = Get-ReceiveConnector -Server $SourceExchangeServer -DomainController $DomainController | Where-Object -FilterScript {$_.Name -notlike "*Default*" -and $_.Name -notlike "*Client*" -and $_.Name -notlike "*Proxy*"}

function menu($DomainController,$SourceExchangeServer,$NewExchangeServer,$ReceiveConnectors)  {

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
    echo ""
    echo "---------------------------------------------------------" 
    echo ""    

    $choice = Read-Host "Which Connector do you want to copy? (Example: 1 or Strg+C to quit)"
    $SelectedConnector = $ReceiveConnectors[($choice-1)]

    $SelectedConnector | foreach {

        if ($_.usage -eq $null) {$usage = "custom"} else {$usage = $_.usage }

        $Parameters = @{
            Usage = "$usage"
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
        New-ReceiveConnector @parameters -DomainController $DomainController
    }

    $ReceiveConnectorPermissions=Get-ReceiveConnector -Identity $SelectedConnector.Identity | Get-ADPermission | ? {$_.ExtendedRights -ne $null} | select-object identity,user,extendedrights
    $TargetConnector = Get-ReceiveConnector -Identity "$NewExchangeServer\$($SelectedConnector.name)"

    foreach ($entry in $ReceiveConnectorPermissions){
        Get-ReceiveConnector $TargetConnector | add-ADPermission -User $entry.user -ExtendedRights $entry.ExtendedRights
    }
}

menu -DomainController $DomainController -SourceExchangeServer $SourceExchangeServer -NewExchangeServer $NewExchangeServer -ReceiveConnectors $ReceiveConnectors 