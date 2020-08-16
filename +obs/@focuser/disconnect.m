function disconnect(Focuser)
% close the serial stream, but don't delete it from workspace
   Focuser.Handle.disconnect;
   Focuser.LastError = Focuser.Handle.lastError;
end
