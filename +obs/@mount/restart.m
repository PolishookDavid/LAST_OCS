function Obj=restart(Obj)
% what's the use case of this method?? Is it because have lost connection
%  to the USB-serial port (in that case we shouldn't just do a
%  search-connect, we should resolve the physcal USB link to determine the
%  new name of the serial port) or is it because the controllers need
%  to be reset (but are still at the same serial resource)
    Obj.Handle.reset % currently only implemented for Xerxes
    
% I DON'T WANT TO SEE THIS CRAP IN AN ABSTRACTION CLASS
%     % restart the xerxes mount handle
%     Obj.Handle.disconnect
%     Obj.Handle.delete
%     X = inst.XerxesMount;
%     X.connect;
%     Obj.Handle = X;
end
