function rsync2euler(Year,Month,Day)
% rsync DirName to euler archive/LAST


DataDir = '/media/last/data2/raw/';

FullDir = sprintf('%s%s/.',DataDir,DirName);

ServerPath = '/var/www/html/data/archive/LAST/';
Server   = 'eran@euler1.weizmann.ac.il';

PWD = pwd;
cd(DataDir)
CmdRun = sprintf('rsync -avx ./ %s:%s%04d/%04d%02d%02d/',Server,ServerPath,Year,Year,Month,Day);

system(CmdRun);

cd(PWD);
