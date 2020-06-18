function DirName = constructDirName()
% Construct directory name to save image in
   BaseDir = '/home/last/data/raw/';
   T = celestial.time.jd2date(floor(celestial.time.julday));
   DirName = sprintf('%s%d%02d%02d',BaseDir, T(3), T(2), T(1));
   if (~exist(DirName,'dir'))
      % create dir
      mkdir(DirName);
   end

