# LUKS Encryption with IBM Cloud Block Storage and IBM Key Protect
This is a basic example for IBM Key Protect with IBM Cloud Block Storage.
- [Overview](#Overview)
- [Architecture](#Architecture)
- [Requirements](#Requirements)
- [API](#api)
  * [toc.plugin](#tocplugin)
  * [toc.json](#tocjson)
  * [toc.insert](#tocinsert)
  * [Utility functions](#utility-functions)
- [About](#about)

## Overview

This example shows:
- Configuring Block Storage in IBM Cloud to be used by a Virtual Machine based on Ubuntu Linux 16.04 LTS  
- Mounting IBM Cloud Block Storage with multi-path tools
- Encrypting the block device with LUKS using a key retrieved from IBM Key Protect using an IAM Service ID API Key
- Basic curl and shell scripting

## Architecture
todo: include picture

The Block Storage Device will as iSCSI using multi-path tools in Ubuntu. The configuration and principle is described in the following guides:
- [Mounting Block Storage in IBM Cloud][1]
- [Configuration of iSCSI in Ubuntu Linux][2]

Once properly configured the Block Storage Device will be used to create a partition table and partition to be accessible by the Operating System.
In IBM Key Protect a custom Root Key is defined, Root Keys could never leave the HSM Box behind the service. With this Root Key a Data Encryption Key DEK is created via API Call. This unwrapped DEK is passed to cryptsetup luksFormat to create an Encrypted LUKS Partition. The DEK is also returned as wrapped DEK which could only be unwrapped by the Root Key stored in Key Protect and the call to the Keyprotect API. This wrapped DEK is stored on the Filesystem in a text file. After the encrypted partition is created a normal EXTFS4 Partition is created into that partition.
To mount the enycrypted partition we need the unwrapped key data for an API Call to unwrap (decrypt) the DEK with the Root Key. The unwrapped Key is passed to cryptsetup luksOpen. This concept is called [Envelope Encryption][3]

## Requirements
- Full IBM Cloud account with IaaS permission to provision block storage and virtual machines.
- An existing Virtual Machine with Ubuntu Linux 16.04 LTS in the IBM Cloud accessible via ssh with public and private network connection.  

## Installation
### 1. Order Blockstorage in the IBM Cloud portal in the Data Center of your Virtual Machine

<img src="doc/01-OrderBlockStorage.png" width="500">

### 2. Authorize the VM for the storage
![trust](doc/02-TrustBlockStorage.png)

<img src="doc/03-TrustBlockStorage.png height: 50% width: 50%>

This will create access credentials.

### 3. Get the iSCSI credentials for IBM Block Storage
On the details Page of the IBM Block Storage you will  find the following Information.
- The target IP Addresses of the iSCSI Provider
![iqn](doc/05-IQN.png)
- Username
- Password
- Host IQN  (iSCSI qualified name)
Please note down that information for later
![iqn](doc/04-IQN.png)

### 4. Configure IBM Key Protect
Create a new Instance of IBM Key Protect in your IBM Cloud Account and add a new **Root Key** and note the Root Key Id, Root Keys never leave the Key Protect Service
![iqn](doc/06-KPKey.png)
Copy the Root Key Id to the clipboard
![iqn](doc/07-KPKey.png)


## Disclaimer
This is a Proof-of-Concept and should not to be used as a full production example without further hardening of the code:
- use compiled code instead of a shell script
- ask for IAM Service Id API key with password input
- clear the memory after the unwrapped DEK is passed to cryptsetup luksOpen
- rotate Root Keys often
- use code obfuscation techniques

## References
[1]: https://console.bluemix.net/docs/infrastructure/BlockStorage/accessing_block_storage_linux.html#mounting-block-storage-volumes
[2]: https://www.server-world.info/en/note?os=Ubuntu_18.04&p=iscsi&f=3
[3]:
https://console.bluemix.net/docs/services/key-protect/concepts/envelope-encryption.html#overview
