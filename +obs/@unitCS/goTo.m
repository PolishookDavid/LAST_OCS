function varargout=goTo(UnitObj,varargin)
    % goto - see obs.mount.goToTarget            
    [varargout{1:1:nargout}] = UnitObj.Mount.goToTarget(varargin{:});
end
