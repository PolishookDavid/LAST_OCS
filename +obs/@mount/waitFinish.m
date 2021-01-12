function Flag = waitFinish(MountObj)
% wait (blocking) until the mount ended slewing and returned to idle mode
   Flag = false;
   pause(2)
   Continue = true;
   while Continue
       pause(1)
       try
           Status = MountObj.Status;
       catch
           pause(1);
           Status = MountObj.Status;
       end
      
   
       switch lower(Status)
           case {'idle','tracking','home','park','aborted'}

                if MountObj.Verbose
                    fprintf('\nSlewing is complete\n');
                end
                Continue = false;
                Flag = true;
           case 'slewing'
               if MountObj.Verbose
                    fprintf('.');
               end
           otherwise
               MountObj.LastError = ['A problem has occurd with the mount. Status: ', Status];
               Continue = false;
       end
   end
end
