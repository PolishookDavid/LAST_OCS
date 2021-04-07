function DirName = constructDirName(DirType)
% Construct directory name to save image in

   % DirType is raw, proc, log, cat
   if (strcmpi(DirType, 'raw') || strcmpi(DirType, 'proc') || strcmpi(DirType, 'log') || strcmpi(DirType, 'cat'))

      % Directory name of 6Tb disk
      % Old config file reading (before Dec 2020):
%      BaseDir = obs.util.config.readSystemConfigFile('ImagesBaseDir');
      % New config file reading (after Dec 2020):
      
      Config = configfile.read_config('config.node.txt');
      
      BaseDir = Config.ImagesBaseDir;

      
      %BaseDir = '/media/last/data2/';
      if (exist(BaseDir,'dir'))
         % Construct daily directory - new version: YYYY/MM/DD/TYPE/
         % Change on Dec 9 2020.
         T = celestial.time.jd2date(floor(celestial.time.julday));
         MonthStr = sprintf('%02d', T(2));
         DayStr = sprintf('%02d', T(1));
         DirName = [BaseDir,filesep, num2str(T(3)),filesep, MonthStr,filesep, DayStr,filesep, DirType,filesep];
         if (~exist(DirName,'dir'))
            % create dir
            mkdir(DirName);
         end

%          % Construct daily directory - old version: TYPE/YYYYMMDD/
%          BaseDir = [BaseDir,filesep,DirType,filesep];
%          % Construct daily directory
%          T = celestial.time.jd2date(floor(celestial.time.julday));
%          DirName = sprintf('%s%d%02d%02d',BaseDir, T(3), T(2), T(1));
%          if (~exist(DirName,'dir'))
%             % create dir
%             mkdir(DirName);
%          end

      else
         error('>>>>>> Disks must be mounted before operations!')
      end
   else
      fprintf('Wrong directory type used! Use: raw, proc, log, cat, only!\n')
   end

