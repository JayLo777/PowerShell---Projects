#Enable Recycle Bin Challenge: Using PowerShell to Enable the Recycle Bin on a Drive
Enable-ADOptionalFeature -Identity 'Recycle Bin Feature' -scope ForestOrConfigurationSet `
-Target 'Adatum.com' -Confirm:$false