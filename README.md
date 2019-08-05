# AD-Password-Auditor

AD-Password-Auditor is Powershell tool to quickly evaluate password security for Active Directory accounts. It is a wrapper script for [DSInternals](https://github.com/MichaelGrafnetter/DSInternals). It performs a dictionary attack on the stored password hashes, and outputs a file with the cracked login/password combinations. 

## Getting started

AD-Password-Auditor is a simple Powershell wrapper script. To launch it :

    .\AD-Password-Auditor.ps1 -Server [dc name] -Domain [domain] -MaxThreads 2 -WordlistDirectory [directory path] -ResultDirectory [directory path]

### Arguments

 - **Server**
     + Specifies the target computer for the operation. Enter a fully qualified domain name (FQDN), a NetBIOS name, or an IP address. When the remote computer is in a different domain than the local computer, the fully qualified domain name is required.
 - **Domain**
     + Speficies the target domain for the operation. Enter the AD domain in DN format. Eg: `DC=mycompany,DC=group`
 - **MaxThreads**
     + Sets the maximum number of concurrent jobs to be run. Allowed values are ints between 1 and 10. It is recommended to enter a value smaller than the number of logical cores your machine has.
 - **WordlistDirectory**
     + The directory where the wordlist dictionaries are stored.
 - **ResultDirectory**
     + The directory where AD-Password-Auditor will output its results and the consolidated results.


## Requirements

### DSInternals

[DSInternals](https://github.com/MichaelGrafnetter/DSInternals) is Powershell module providing cmdlets to evaluate password security.

Install it on your machine by running the following command in an Powershell terminal with admin privileges:

    Install-Module -Name DSInternals

### Wordlists

You can find wordlists anywhere on the Internet. You can also generate your own by using a tool such as [Mentalist](https://github.com/sc0tfree/mentalist).

### User

The script uses the privileges that the user launching it has on the AD. If you do not have an AD account, or the correct permissions, you will not be able to run the script successfully.

## Performance

AD-Password-Auditor only uses the CPU to process the hashes and wordlists. As a result, it is not as efficient as GPU-based evaluation methods. It is however much easier to deploy and run on any machine that can reach the targeted Active Directory.

### Multithreading

The script can launch multiple cracking jobs simultaneously. Every job runs on a single dictionary file. As such, it is recommended to provide multiple wordlist files and run more than one thread to accelerate the cracking job.

Cracking is a CPU intensive task. For optimum results, it is recommended to launch the script with `-MaxThreads` set at `n-1` where `n` is the number of logical cores your machine has.

### Wordlist size

Wordlists are loaded in RAM. It is recommended to provide wordlists smaller than 500Mb to avoid significant slowdowns.
