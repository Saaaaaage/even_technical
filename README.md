# FLAWS 2 Defender

## Installation

1. Install Ruby
2. Install AWS SDK gems
   * `gem install aws-sdk-s3 aws-sdk-iam aws-sdk-ecr`
3. Setup AWS Creds
   * http://flaws2.cloud/defender.htm

## Workflow

#### Download logs

Logs are expected to be held in S3 buckets.  The credentials used to connect to AWS should only be concerned with logs, as all S3 buckets will be treated as containing logs.

#### Search for ANONYMOUS_PRINCIPAL attacks

Logs are scanned for usage of ANONYMOUS_PRINCIPAL

#### Validate ANONYMOUS_PRINCIPAL usage

The ANONYMOUS_PRINCIPAL attack pattern will have the hacker connecting from a non-AWS IP address.  If ANONYMOUS_PRINCIPAL was connected from an AWS IP then the logs do not reflect the attack we're searching for.

#### Check if other accounts were compromised

This is done by checking if the same IP address was used to issue commands without using ANONYMOUS_PRINCIPAL.  At the same time we check compromised user policies to see if they're allowed to be used from non-AWS IP addresses.

#### Check for compromised repositories

See if any repositories were accessed and validate their policies for vulnerabilities.

##  The Termite Class

Because it goes through logs!

On initialization the Termite class accepts a directory to recursively search for json files.  It is expected that all files in this directory with a .json extension are log files to be loaded.  All logs discovered are held in memory.

#### Termite#query_logs(query)

`query_logs` returns filtered logs. The function expects a hash object whose keys represent the fields to be validated and values represent the value to be matched in the log.  When searching a JSON embedded object, a path given in the hash key will traverse the log object to the correct location.  Multiple keys in the hash will work as an AND filter. The hash values can be REGEX or strings.

EG:

    query = {
        'userIdentity.accountId' => /^ANONYMOUS.*/,
        'sourceIPAddress' => '104.102.221.250'
    }
    matched_logs = termite_instance.query_logs(query)
