function update_time_NTP
% update computer time using NTP

Password = 'Physics';
% need to set password automatically
system('export HISTIGNORE=''*sudo -S*''')
system(sprintf('echo "%s" | sudo -S -k ntpdate -qu 1.ro.pool.ntp.org', Password))

