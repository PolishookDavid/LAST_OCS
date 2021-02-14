function setCoordinate(MountObj,NewRA,NewDec,MountRA,MountDec,CooSys)
% Set the mount encoder coordinates to a given values (RA/Dec)
% Package: +obs/@mount
% Description: Declare that the current mount position (or an arbitrary position
%              if more arguments are supplied) has effectively given RA,Dec
%              coordinates. This is done by shifting .HAZeroPositionTicks and 
%              .DecZeroPositionTicks of such amounts that the request is fullfilled
% Input  : - New RA [deg] position, will set the mount RA to this value.
%          - New Dec [deg] position, will set the mount Dec to this value.
%          - Mount RA [deg]. If not provided than will read from the
%            current mount RA. This is always given in Equinox of date.
%          - Mount Dec [deg]. If not provided than will read from the
%            current mount Dec. This is always given in Equinox of date.
%          - Coordinate system of the New RA/Dec: 'J2000' | 'jdate'.
%            Default is 'J2000'.
%            Note that the Mount RA/Dec are always in Equinox of date.
%
% Usage:
%
%  X.setCoordinate(newRA,newDec)  corrects the encoders offsets so that the
%                                 current mount position is read as (newRA,newDec)
%                                 All coordinates are in Equinox of Date
%                                 [deg]
%
%  X.setCoordinate(newRA,newDec,RA,Dec)  corrects the encoders offsets so that
%                                        what is now (RA,Dec) will be pointed
%                                        to as (newRA,newDec)
%                                        All coordinates are in Equinox of
%                                        Date [deg]
%
%  Note: in a simplicistic way, this is done simply adding to the encoder zero
%        positions the differences between old and new coordinates.
%        Beware!!
%        Funny things may happen for large corrections, or for corrections
%        which involve changing flip quadrant (i.e. involving one of the two
%        sets below the celestial north pole, Dec==180-MotorDec)
% Examples:
%       M.setCoordinate(newRA,newDec,mountRA,mountDec)
%       M.setCoordinate(newRA,newDec)
%       By : Eran O. Ofek                        Feb 2021
% Tested   : 12-02-2021/Eran



RAD = 180./pi;

if nargin==6
    % all parameters are supplied by the user
elseif nargin==5
    CooSys = 'J2000';
elseif nargin==3
    MountRA  = MountObj.RA;
    MountDec = MountObj.Dec;
    CooSys   = 'jdate';
elseif nargin==2
       
    if ischar(NewRA)
        switch lower(NewRA)
            case 'reset'
                MountRA  = MountObj.RA;
                MountDec = MountObj.Dec;
                NewRA    = MountRA;
                NewDec   = MountDec;
            otherwise
                error('Unknown string option in second input argument');
        end
    else
        error('Illegal input arguments');
    end
else
    error('Illegal input arguments');
end

% convert coordinate systems
switch lower(CooSys)
    case {'jdate','jnow'}
        % do nothing
        % NewRA, NewDec are already in Equinox of date
    case {'j2000.0','j2000'}
        % NewRA, NewDec are given in J2000
        % convert [NewRA,NewDec] to Jnow
        JD = celestial.time.julday; % JD, UTC now
        JnowStr = sprintf('j%8.3f',convert.time(JD,'JD','J'));
        NewCoo  = celestial.coo.coco([NewRA,NewDec]./RAD,'j2000.0',JnowStr);
        NewRA   = NewCoo(1).*RAD;
        NewDec  = NewCoo(2).*RAD;
    otherwise
        error('Unknown CooSys option');
end

% update the encoders position
MountObj.Handle.setCoordinate(NewRA,NewDec,MountRA,MountDec);
 
%--- write new setting to the configuration file ---
% prepare strings of [NewRA, MountRA] for configuration file
OffsetRAstr  = sprintf('[%12.8f %12.8f]',NewRA,MountRA);
OffsetDecstr = sprintf('[%12.8f %12.8f]',NewDec,MountDec);
% store the strings in the configuration file










% HA_Offset  = abs(newRA - ra);   % deg
% Dec_Offset = abs(newDec - dec); % deg
% 
% 
% 
%    if nargin == 3
%         newDec = dec;
%         dec    = MountObj.Dec;
%         newRA  = ra;
%         ra     = MountObj.RA;
%    elseif nargin == 5
%         % Do nothihng
%    else
%        error('Wrong number of arguments. Give new RA & Dec for correcting current coordinates, or specific RA & Dec and their new values')
%    end
%    
%    % Temporal value (and location) - figure out the correct threshold! DP Feb 2021
%    LargeCorrection = 45; % Units of degrees
%    
%    RAcorrection = abs(newRA - ra);
%    DecCorrection = abs(newDec - dec);
% 
%    if (LargeCorrection <= RAcorrection | LargeCorrection <= DecCorrection)
%       Reply = input('This is a large correction! Are you sure you want to set these coordinates (y/n)?','s');
%       if isempty(Reply)
%          Reply='y';
%       end
% 
%       switch lower(Reply)
%          case {'y'}
%             MountObj.Handle.setCoordinate(ra,dec,newRA,newDec)
%          otherwise
%             disp('Cancel coordinate setting.')
%       end
%    end
%    
% end