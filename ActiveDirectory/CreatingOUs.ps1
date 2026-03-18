#Creating OUs | Creating a User Account in an OU named San Diego | Removing User Accounts in an OU named San Diego

Get-Module -ListAvailable ActiveDirectory
#Loads AD commands into PS

Import-Module ActiveDirectory

#Finding the Domain Path
Get-ADDomain   #<DC=Adatum,DC=com>
New-ADOrganizationalUnit -Name "San Diego" -Path "DC=Adatum,DC=com" -ProtectedFromAccidentalDeletion $true
Get-ADOrganizationalUnit -Filter "Name -eq 'San Diego'"