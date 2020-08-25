function DirName = constructDirName(DirType)
% Construct directory name to save image in

   % DirType is raw, proc, log, cat
   if (strcmpi(DirType, 'raw') || strcmpi(DirType, 'proc') || strcmpi(DirType, 'log') || strcmpi(DirType, 'cat'))

      % Directory name of 6Tb disk
      BaseDir = obs.util.config.readSystemConfigFile('ImagesBaseDir');
      %BaseDir = '/media/last/data2/';
      if (exist(BaseDir,'dir'))
         BaseDir = [BaseDir,filesep,DirType,filesep];

         % Construct daily directory
         T = celestial.time.jd2date(floor(celestial.time.julday));
         DirName = sprintf('%s%d%02d%02d',BaseDir, T(3), T(2), T(1));
         if (~exist(DirName,'dir'))
            % create dir
            mkdir(DirName);
         end
      else
         error('>>>>>> Disks must be mounted before operations!')
      end
   else
      fprintf('Wrong directory type used! Use: raw, proc, log, cat, only!\n')
   end

