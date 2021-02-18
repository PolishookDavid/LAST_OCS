function Obj=restart(Obj)
% restart the xerxes mount handle



Obj.Handle.disconnect
Obj.Handle.delete

X = inst.XerxesMount;
X.connect;
Obj.Handle = X;
