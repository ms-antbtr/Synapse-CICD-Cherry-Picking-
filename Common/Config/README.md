# Overview

JSON config files used to produce environment-specific ARM template parameter and Synapse resource files at build time

## Schema validation

The contents of the active configuration files in this folder are validated against the [/environment_config.schema.json](environment_config.schema.json) file during the build. This path is currently **AzurePipeline/Config/Schema/environment_config.schema.json**.

Configuration files can be commented out/excluded by prefixing the file name with an underscore ("_").

> Note: there is not a shared function to retrieve the list of "active" configurations. This logic should be included anywhere you read a list of files from the config folder. This is the PowerShell logic:

```ps
$ConfigFiles = Get-ChildItem -Path $ConfigPath -Filter *.json | Where-Object { -not $_.Name.StartsWith('_') }
```

## Parameter usage (-ConfigPath)

This path is commonly referred to as `-ConfigPath`. Any function or script that takes this folder as a parameter must use this parameter name for consistency and simplify reuse.

### SAW IP range configuration

From [SAW datacenter IP ranges (SharePoint)](https://microsoft.sharepoint.com/sites/Security_Tools_Services/SitePages/SAS/saw%20kb/saw-datacenter-ip-ranges.aspx)

```json
[
    {
        "EndIpAddress": "25.7.255.255",
        "Name": "SAW_APAC_CorpNet_25.7.0.0_16",
        "StartIpAddress": "25.7.0.0"
    },
    {
        "EndIpAddress": "167.220.249.191",
        "Name": "SAW_APAC_E3_167.220.249.128_26",
        "StartIpAddress": "167.220.249.128"
    },
    {
        "EndIpAddress": "13.106.4.127",
        "Name": "SAW_APAC_legacy_13.106.4.96_27",
        "StartIpAddress": "13.106.4.96"
    },
    {
        "EndIpAddress": "25.4.255.255",
        "Name": "SAW_CPDC_CorpNet_25.4.0.0_16",
        "StartIpAddress": "25.4.0.0"
    },
    {
        "EndIpAddress": "157.58.216.",
        "Name": "SAW_CPDC_E3_157.58.216.64_26",
        "StartIpAddress": "157.58.216.64"
    },
    {
        "EndIpAddress": "207.68.190.63",
        "Name": "SAW_CPDC_Legacy_207.68.190.32_27",
        "StartIpAddress": "207.68.190.32"
    },
    {
        "EndIpAddress": "25.6.255.255",
        "Name": "SAW_Dublin_CorpNet_25.6.0.0_16",
        "StartIpAddress": "25.6.0.0"
    },
    {
        "EndIpAddress": "194.69.119.127",
        "Name": "SAW_Dublin_E3_194.69.119.64_26",
        "StartIpAddress": "194.69.119.64"
    },
    {
        "EndIpAddress": "13.106.174.63",
        "Name": "SAW_Dublin_legacy_13.106.174.32_27",
        "StartIpAddress": "13.106.174.32"
    },
    {
        "EndIpAddress": "25.5.255.255",
        "Name": "SAW_MOPR_CorpNet_25.5.0.0_16",
        "StartIpAddress": "25.5.0.0"
    },
    {
        "EndIpAddress": "13.106.78.63",
        "Name": "SAW_MOPR_Legacy_13.106.78.32_27",
        "StartIpAddress": "13.106.78.32"
    }
]
```

### Corp IP range configuration

```json
[
    {
        "EndIpAddress": "167.220.227.255",
        "Name": "Corp_Bangalore_167.220.226.0_23",
        "StartIpAddress": "167.220.226.0"
    },
    {
        "EndIpAddress": "167.220.149.255",
        "Name": "Corp_Bristow_167.220.148.0_23",
        "StartIpAddress": "167.220.148.0"
    },
    {
        "EndIpAddress": "157.58.212.191",
        "Name": "Corp_Cheyenne_157.58.212.128_26",
        "StartIpAddress": "157.58.212.128"
    },
    {
        "EndIpAddress": "157.58.212.127",
        "Name": "Corp_Cheyenne_157.58.212.64_26",
        "StartIpAddress": "157.58.212.64"
    },
    {
        "EndIpAddress": "157.58.213.255",
        "Name": "Corp_Cheyenne_157.58.213.192_26",
        "StartIpAddress": "157.58.213.192"
    },
    {
        "EndIpAddress": "157.58.213.127",
        "Name": "Corp_Cheyenne_157.58.213.64_26",
        "StartIpAddress": "157.58.213.64"
    },
    {
        "EndIpAddress": "157.58.214.191",
        "Name": "Corp_Cheyenne_157.58.214.128_26",
        "StartIpAddress": "157.58.214.128"
    },
    {
        "EndIpAddress": "157.58.214.255",
        "Name": "Corp_Cheyenne_157.58.214.192_26",
        "StartIpAddress": "157.58.214.192"
    },
    {
        "EndIpAddress": "94.245.87.255",
        "Name": "Corp_Dublin_94.245.87.0_24",
        "StartIpAddress": "94.245.87.0"
    },
    {
        "EndIpAddress": "167.220.204.191",
        "Name": "Corp_Herzliya_167.220.204.128_26",
        "StartIpAddress": "167.220.204.128"
    },
    {
        "EndIpAddress": "167.220.204.255",
        "Name": "Corp_Herzliya_167.220.204.192_26",
        "StartIpAddress": "167.220.204.192"
    },
    {
        "EndIpAddress": "167.220.205.63",
        "Name": "Corp_Herzliya_167.220.205.0_26",
        "StartIpAddress": "167.220.205.0"
    },
    {
        "EndIpAddress": "167.220.205.127",
        "Name": "Corp_Herzliya_167.220.205.64_26",
        "StartIpAddress": "167.220.205.64"
    },
    {
        "EndIpAddress": "167.220.238.31",
        "Name": "Corp_Hyderabad_167.220.238.0_27",
        "StartIpAddress": "167.220.238.0"
    },
    {
        "EndIpAddress": "167.220.238.159",
        "Name": "Corp_Hyderabad_167.220.238.128_27",
        "StartIpAddress": "167.220.238.128"
    },
    {
        "EndIpAddress": "167.220.238.223",
        "Name": "Corp_Hyderabad_167.220.238.192_27",
        "StartIpAddress": "167.220.238.192"
    },
    {
        "EndIpAddress": "167.220.238.95",
        "Name": "Corp_Hyderabad_167.220.238.64_27",
        "StartIpAddress": "167.220.238.64"
    },
    {
        "EndIpAddress": "167.220.197.255",
        "Name": "Corp_London_167.220.196.0_23",
        "StartIpAddress": "167.220.196.0"
    },
    {
        "EndIpAddress": "167.220.70.127",
        "Name": "Corp_Quincy_167.220.70.64_26",
        "StartIpAddress": "167.220.70.64"
    },
    {
        "EndIpAddress": "167.220.76.255",
        "Name": "Corp_Quincy_167.220.76.192_26",
        "StartIpAddress": "167.220.76.192"
    },
    {
        "EndIpAddress": "167.220.77.127",
        "Name": "Corp_Quincy_167.220.77.64_26",
        "StartIpAddress": "167.220.77.64"
    },
    {
        "EndIpAddress": "167.220.80.255",
        "Name": "Corp_Quincy_167.220.80.192_26",
        "StartIpAddress": "167.220.80.192"
    },
    {
        "EndIpAddress": "167.220.81.191",
        "Name": "Corp_Quincy_167.220.81.128_26",
        "StartIpAddress": "167.220.81.128"
    },
    {
        "EndIpAddress": "167.220.81.255",
        "Name": "Corp_Quincy_167.220.81.192_26",
        "StartIpAddress": "167.220.81.192"
    },
    {
        "EndIpAddress": "131.107.132.31",
        "Name": "Corp_Redmond-CCND_131.107.132.16_28",
        "StartIpAddress": "131.107.132.16"
    },
    {
        "EndIpAddress": "131.107.132.47",
        "Name": "Corp_Redmond-CCND_131.107.132.32_28",
        "StartIpAddress": "131.107.132.32"
    },
    {
        "EndIpAddress": "131.107.1.255",
        "Name": "Corp_Redmond_131.107.1.128_25",
        "StartIpAddress": "131.107.1.128"
    },
    {
        "EndIpAddress": "131.107.132.31",
        "Name": "Corp_Redmond_131.107.132.16_28",
        "StartIpAddress": "131.107.132.16"
    },
    {
        "EndIpAddress": "131.107.132.47",
        "Name": "Corp_Redmond_131.107.132.32_28",
        "StartIpAddress": "131.107.132.32"
    },
    {
        "EndIpAddress": "131.107.147.255",
        "Name": "Corp_Redmond_131.107.147.0_24",
        "StartIpAddress": "131.107.147.0"
    },
    {
        "EndIpAddress": "131.107.159.255",
        "Name": "Corp_Redmond_131.107.159.0_24",
        "StartIpAddress": "131.107.159.0"
    },
    {
        "EndIpAddress": "131.107.160.255",
        "Name": "Corp_Redmond_131.107.160.0_24",
        "StartIpAddress": "131.107.160.0"
    },
    {
        "EndIpAddress": "131.107.174.255",
        "Name": "Corp_Redmond_131.107.174.0_24",
        "StartIpAddress": "131.107.174.0"
    },
    {
        "EndIpAddress": "131.107.8.127",
        "Name": "Corp_Redmond_131.107.8.0_25",
        "StartIpAddress": "131.107.8.0"
    },
    {
        "EndIpAddress": "167.220.1.255",
        "Name": "Corp_Redmond_167.220.0.0_23",
        "StartIpAddress": "167.220.0.0"
    },
    {
        "EndIpAddress": "167.220.2.255",
        "Name": "Corp_Redmond_167.220.2.0_24",
        "StartIpAddress": "167.220.2.0"
    },
    {
        "EndIpAddress": "167.220.24.255",
        "Name": "Corp_SantaClara_167.220.24.0_24",
        "StartIpAddress": "167.220.24.0"
    },
    {
        "EndIpAddress": "167.220.26.255",
        "Name": "Corp_SantaClara_167.220.26.0_24",
        "StartIpAddress": "167.220.26.0"
    },
    {
        "EndIpAddress": "191.234.97.63",
        "Name": "Corp_SaoPaulo_191.234.97.0_26",
        "StartIpAddress": "191.234.97.0"
    },
    {
        "EndIpAddress": "167.220.255.127",
        "Name": "Corp_Singapore_167.220.255.0_25",
        "StartIpAddress": "167.220.255.0"
    },
    {
        "EndIpAddress": "167.220.242.31",
        "Name": "Corp_Sydney_167.220.242.0_27",
        "StartIpAddress": "167.220.242.0"
    },
    {
        "EndIpAddress": "167.220.242.159",
        "Name": "Corp_Sydney_167.220.242.128_27",
        "StartIpAddress": "167.220.242.128"
    },
    {
        "EndIpAddress": "167.220.242.223",
        "Name": "Corp_Sydney_167.220.242.192_27",
        "StartIpAddress": "167.220.242.192"
    },
    {
        "EndIpAddress": "167.220.242.95",
        "Name": "Corp_Sydney_167.220.242.64_27",
        "StartIpAddress": "167.220.242.64"
    },
    {
        "EndIpAddress": "194.69.104.127",
        "Name": "Corp_Tallinn_194.69.104.0_25",
        "StartIpAddress": "194.69.104.0"
    },
    {
        "EndIpAddress": "167.220.233.255",
        "Name": "Corp_Tokyo_167.220.232.0_23",
        "StartIpAddress": "167.220.232.0"
    }
]
```
