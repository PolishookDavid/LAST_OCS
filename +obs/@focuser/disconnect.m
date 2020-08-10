function disconnect(Foc)
% close the serial stream, but don't delete it from workspace
   Foc.FocHn.disconnect;
   Foc.LastError = Foc.FocHn.lastError;
end
