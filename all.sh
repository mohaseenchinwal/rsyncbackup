#!/bin/bash


DATE=`/bin/date +%a---%d/%m/%y`

`/bin/bash /home/ansible/bkpscript/pushv1.sh mgmt1.sec.qaregistry.local ansible.sec.qaregistry.local netmon1.sec.qaregistry.local`

`/bin/cat /var/log/rsync/exitstatus | /bin/mail -s "Secondary Servers Backup Status on $DATE" mchinwal\@cra.gov.qa`

#`/bin/cat /var/log/rsync/exitstatus | /bin/mail -s "Secondary Servers Backup Status on $DATE" omohammed\@cra.gov.qa`

#`/bin/cat /var/log/rsync/exitstatus | /bin/mail -s "Secondary Servers Backup Status on $DATE" tech\@domains.qa`
