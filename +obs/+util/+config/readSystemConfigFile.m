function Output = readSystemConfigFile(Keyword)
% Read a configuration file for the system connected to this computer, and
% retrieve the fixed Keywords.
% Only superuser can modify the configuration file

ConfigDirectory = '/home/last/config/';  % this should be an environoment variable
%ConfigDirectory = '/home/eran/config/';  % this should be an environoment variable
ConfigTable=readtable([ConfigDirectory,'ObsSystemConfig.txt']);

if nargin < 1
   Output=ConfigTable;
else
   Mask = ismember(ConfigTable.Keyword, Keyword);
   ValueTemp = ConfigTable(Mask,2);
   if (~isempty(ValueTemp))
      Units = ConfigTable(Mask,3);
      if (~strcmp(Units.Units{1}, 'str'))
         Output = eval(ValueTemp.Value{1});
      else
         Output = ValueTemp.Value{1};
      end
   else
      Output = NaN;
   end
end



% Older version

% if(strcmp(Keyword, 'MountLongitude') || strcmp(Keyword, 'MountLatitude'))
%    Value = regexp(ConfigFile,[Keyword,';(\w*.\w*)'],'tokens');
% else
%    Value = regexp(ConfigFile,[Keyword,';(\w*)'],'tokens');
% end
% if(~isempty(Value))
%    Output = Value{1}{1};
% else
%    Output = nan;
% end
